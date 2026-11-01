package com.akletna.backend.service;

import com.akletna.backend.dto.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.exception.*;
import com.akletna.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.util.*;

@Service
public class GroceryListService {
    private final GroceryListRepository lists;
    private final GroceryItemRepository items;
    private final MealPlanRepository plans;
    private final UserService users;
    private final UserRepository userRepository;
    private final GroceryContributionRepository contributions;
    private final RecipeService recipes;
    private final PantryItemRepository pantry;
    private final PantryMatchingService matching;

    public GroceryListService(GroceryListRepository lists,GroceryItemRepository items,MealPlanRepository plans,
            UserService users,UserRepository userRepository,GroceryContributionRepository contributions,
            RecipeService recipes,PantryItemRepository pantry,PantryMatchingService matching) {
        this.lists=lists;this.items=items;this.plans=plans;this.users=users;this.userRepository=userRepository;
        this.contributions=contributions;this.recipes=recipes;this.pantry=pantry;this.matching=matching;
    }
    // One owner lock serializes first-list creation, duplicate additions and all grocery writes.
    private User owner(String email) {
        var user=users.getUserByEmail(email);
        return userRepository.findLockedById(user.getId()).orElseThrow(()->new ResourceNotFoundException("User not found."));
    }
    private GroceryList list(User user) {
        return lists.findByUser(user).orElseGet(()->lists.save(new GroceryList(user,LocalDateTime.now())));
    }
    @Transactional(readOnly=true)
    public GroceryListResponse getOrCreateUserGroceryList(String email) {
        var list=lists.findByUser(users.getUserByEmail(email)).orElse(null);
        return list == null ? new GroceryListResponse(null,null,List.of())
                : response(list,contributions.findByGroceryListOrderByIdAsc(list));
    }
    @Transactional
    public GroceryListResponse generateFromMealPlans(GroceryGenerateRequest request,String email) {
        if (request != null && (request.getStartDate() == null) != (request.getEndDate() == null))
            throw new BadRequestException("Provide both startDate and endDate, or neither.");
        var user=owner(email);
        List<MealPlan> selected;
        if(request!=null && request.getStartDate()!=null && request.getEndDate()!=null) {
            if(request.getStartDate().isAfter(request.getEndDate())) throw new BadRequestException("startDate cannot be after endDate");
            selected=plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(user,request.getStartDate(),request.getEndDate());
        } else selected=plans.findByUserOrderByDateAscMealTypeAsc(user);
        var requirements=new ArrayList<GroceryContributionLine>();
        for(var plan:selected) {
            var snapshot=plan.getSnapshot();
            if(snapshot==null || !snapshot.isReady()) throw new BadRequestException("A planned meal has unresolved recipe data. Remove it and add a readable recipe again before generating groceries.");
            QuantityScaling.validateServings(snapshot.getBaseServings(),plan.getPlannedServings());
            for(var line:snapshot.getIngredients()) {
                var unit=QuantityUnit.of(line.getUnit());
                var amount=unit.canonicalQuantity(QuantityScaling.effectiveQuantity(line.getQuantity(),plan.getPlannedServings(),snapshot.getBaseServings()));
                requirements.add(new GroceryContributionLine(line.getIngredientId(),line.getIngredientName().trim(),"REQUIRED",amount,
                        unit.dimension()==QuantityUnit.Dimension.OTHER ? unit.symbol() : unit.canonicalUnit()));
            }
        }
        var list=list(user);
        var sources=new ArrayList<>(contributions.findByGroceryListOrderByIdAsc(list));
        var planned=sources.stream().filter(c->c.getSourceKey().equals("PLAN")).findFirst().orElse(null);
        if(planned==null) {
            planned=new GroceryContribution(list,"PLANNED_MEAL","PLAN","Weekly meal plan",null,null,requirements);
            contributions.save(planned);sources.add(planned);
        } else planned.replacePlannedLines(requirements);
        return rebuild(list,sources);
    }
    @Transactional(readOnly=true)
    public RecipeShortageResponse previewShortages(Long recipeId,Integer servings,String email) {
        var recipe=recipes.getRecipeForGrocery(recipeId,email);
        var user=users.getUserByEmail(email);
        QuantityScaling.validateServings(recipe.getServings(),servings);
        var inventory=pantry.findForUser(user.getId());
        var list=lists.findByUser(user).orElse(null);
        var existing=list==null ? null : findContext(contributions.findByGroceryListOrderByIdAsc(list),recipeId,servings);
        if(existing!=null) return shortageResponse(existing,inventory.isEmpty(),"ALREADY_ADDED");
        var lines=shortages(recipe,servings,inventory);
        return new RecipeShortageResponse(recipe.getId(),recipe.getName(),servings,inventory.isEmpty(),
                inventory.isEmpty()?"PANTRY_EMPTY":"PREVIEW",null,lineResponses(lines));
    }
    @Transactional
    public RecipeShortageResponse addShortages(Long recipeId,Integer servings,String email) {
        var user=owner(email);
        var recipe=recipes.getRecipeForGrocery(recipeId,email);
        QuantityScaling.validateServings(recipe.getServings(),servings);
        var inventory=pantry.findForUser(user.getId());
        var list=lists.findByUser(user).orElse(null);
        var sources=list==null ? new ArrayList<GroceryContribution>() : new ArrayList<>(contributions.findByGroceryListOrderByIdAsc(list));
        var existing=findContext(sources,recipeId,servings);
        if(existing!=null) return shortageResponse(existing,inventory.isEmpty(),"ALREADY_ADDED");
        var lines=shortages(recipe,servings,inventory);
        if(lines.stream().noneMatch(l->l.quantity()!=null))
            return new RecipeShortageResponse(recipeId,recipe.getName(),servings,inventory.isEmpty(),
                    inventory.isEmpty()?"PANTRY_EMPTY":"NOTHING_TO_ADD",null,lineResponses(lines));
        if(list==null) list=list(user);
        var addition=new GroceryContribution(list,"RECIPE_SHORTAGE",context(recipeId,servings),recipe.getName(),recipeId,servings,lines);
        contributions.save(addition);sources.add(addition);
        rebuild(list,sources);
        return shortageResponse(addition,false,"ADDED");
    }
    private List<GroceryContributionLine> shortages(Recipe recipe,int servings,List<PantryItem> inventory) {
        if(!matching.valid(recipe)) throw new BadRequestException("This recipe has incomplete requirements and cannot be compared with your pantry.");
        if(inventory.isEmpty()) return List.of(); // No implicit add-all operation.
        var byId=new HashMap<Long,PantryItem>();inventory.forEach(i->byId.put(i.getIngredient().getId(),i));
        return recipe.getIngredients().stream().sorted(Comparator.comparing(l->l.getIngredient().getId())).map(line->{
            var comparison=matching.compareIngredient(line,byId.get(line.getIngredient().getId()),servings,recipe.getServings());
            var amount=switch(comparison.status()) {
                case MISSING -> comparison.required(); case SHORTAGE -> comparison.shortage(); default -> null;
            };
            return new GroceryContributionLine(line.getIngredient().getId(),line.getIngredient().getName(),comparison.status().name(),amount,comparison.unit());
        }).toList();
    }
    private static String context(Long id,int servings){return "RECIPE:"+id+":"+servings;}
    private GroceryContribution findContext(List<GroceryContribution> sources,Long id,int servings) {
        return sources.stream().filter(c->c.getSourceKey().equals(context(id,servings))).findFirst().orElse(null);
    }
    @Transactional
    public GroceryListResponse removeContribution(Long id,String email) {
        var user=owner(email);
        var list=lists.findByUser(user).orElseThrow(()->new ResourceNotFoundException("Grocery contribution not found."));
        var sources=new ArrayList<>(contributions.findByGroceryListOrderByIdAsc(list));
        var removed=sources.stream().filter(c->c.getId().equals(id) && c.getSource().equals("RECIPE_SHORTAGE")).findFirst()
                .orElseThrow(()->new ResourceNotFoundException("Grocery contribution not found."));
        contributions.delete(removed);sources.remove(removed);
        return rebuild(list,sources);
    }
    @Transactional
    public GroceryItemResponse toggleItemChecked(Long id,String email) {
        var user=owner(email);
        var list=lists.findByUser(user).orElseThrow(()->new ResourceNotFoundException("Grocery list not found for current user."));
        var item=items.findByIdAndGroceryList(id,list).orElseThrow(()->new ResourceNotFoundException("Grocery item not found with id: "+id));
        item.setChecked(!item.isChecked());return itemResponse(items.save(item));
    }
    @Transactional
    public void clearGroceryList(String email) {
        var user=owner(email);
        var list=lists.findByUser(user).orElseThrow(()->new ResourceNotFoundException("Grocery list not found for current user."));
        contributions.deleteAll(contributions.findByGroceryListOrderByIdAsc(list));
        list.getItems().clear();list.setUpdatedAt(LocalDateTime.now());lists.save(list);
    }
    private GroceryListResponse rebuild(GroceryList list,List<GroceryContribution> sources) {
        var totals=new LinkedHashMap<Key,Total>();
        for(var source:sources) for(var line:source.getLines()) {
            if(line.quantity()==null) continue;
            var unit=QuantityUnit.of(line.getUnit());
            var identity=line.getIngredientId()!=null ? "INGREDIENT:"+line.getIngredientId() : "LEGACY:"+line.getLegacyItemId();
            var key=new Key(identity,unit.compatibilityKey());
            var quantity=unit.canonicalQuantity(line.quantity());
            totals.compute(key,(k,old)->old==null ? new Total(line.getIngredientName(),unit.dimension()==QuantityUnit.Dimension.OTHER?unit.symbol():unit.canonicalUnit(),quantity)
                    :new Total(old.name(),old.unit(),old.quantity().add(quantity)));
        }
        // Rebuilds reset checks deliberately; duplicate requests never rebuild or reset.
        list.getItems().clear();list.setUpdatedAt(LocalDateTime.now());
        for(var total:totals.values()) list.addItem(new GroceryItem(list,total.name(),total.quantity().rounded(2).doubleValue(),total.unit(),false));
        lists.save(list);return response(list,sources);
    }
    private GroceryItemResponse itemResponse(GroceryItem item){return new GroceryItemResponse(item.getId(),item.getName(),item.getQuantity(),item.getUnit(),item.isChecked());}
    private List<RecipeShortageResponse.Line> lineResponses(List<GroceryContributionLine> lines) {
        return lines.stream().map(l->new RecipeShortageResponse.Line(l.getIngredientId(),l.getIngredientName(),l.getState(),
                l.quantity()==null?null:l.quantity().rounded(12).stripTrailingZeros().toPlainString(),l.getUnit())).toList();
    }
    private RecipeShortageResponse shortageResponse(GroceryContribution source,boolean empty,String status) {
        return new RecipeShortageResponse(source.getRecipeId(),source.getSourceName(),source.getServings(),empty,status,source.getId(),lineResponses(source.getLines()));
    }
    private GroceryListResponse response(GroceryList list,List<GroceryContribution> sources) {
        var result=new GroceryListResponse(list.getId(),list.getUpdatedAt(),list.getItems().stream().map(this::itemResponse).toList());
        result.setContributions(sources.stream().map(s->new GroceryContributionResponse(s.getId(),s.getSource(),s.getSourceName(),s.getRecipeId(),s.getServings(),s.getCreatedAt(),lineResponses(s.getLines()))).toList());
        return result;
    }
    private record Key(String identity,QuantityUnit.CompatibilityKey unit) {}
    private record Total(String name,String unit,QuantityScaling.Quantity quantity) {}
}
