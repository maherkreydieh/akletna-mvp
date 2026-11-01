package com.akletna.backend.service;

import com.akletna.backend.dto.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.exception.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;
import java.util.stream.Collectors;

/** Evolves the original profile without discarding unrecognized legacy selections. */
@Service
public class UserPreferenceService {
    private final UserPreferenceRepository preferences;
    private final UserService users;
    private final UserRepository userRows;
    private final IngredientRepository ingredients;
    public UserPreferenceService(UserPreferenceRepository preferences,UserService users,UserRepository userRows,IngredientRepository ingredients) {
        this.preferences=preferences;this.users=users;this.userRows=userRows;this.ingredients=ingredients;
    }
    @Transactional(readOnly=true)
    public PreferencesResponse getUserPreferences(String email) { return forUser(users.getUserByEmail(email)); }
    @Transactional(readOnly=true)
    public PreferencesResponse forUser(User user) { return response(preferences.findByUser(user).orElseGet(()->new UserPreference(user))); }
    @Transactional
    public PreferencesResponse updateUserPreferences(PreferencesRequest request,String email) {
        var user=users.getUserByEmail(email);
        // Lock the User even when no preference row exists yet; serialize initial creates.
        userRows.findLockedById(user.getId()).orElseThrow(()->new ResourceNotFoundException("User not found."));
        var pref=preferences.findByUser(user).orElseGet(()->new UserPreference(user));
        Set<String> newAllergies=request.getAllergies()==null ? null : canonical(request.getAllergies(),true);
        Set<String> newDiets=request.getDietaryRestrictions()==null ? null : canonical(request.getDietaryRestrictions(),false);
        Set<Ingredient> dislikes=null;
        if(request.getDislikedIngredients()!=null && !request.getDislikedIngredients().isEmpty())
            throw new BadRequestException("Select disliked Ingredient IDs. Legacy ingredient names are preserved for review.");
        if(request.getDislikedIngredientIds()!=null) {
            if(request.getDislikedIngredientIds().size()>50 || request.getDislikedIngredientIds().stream().anyMatch(id->id==null || id<=0))
                throw new BadRequestException("Select up to 50 valid Ingredient IDs.");
            dislikes=new HashSet<>(ingredients.findAllById(request.getDislikedIngredientIds()));
            if(dislikes.size()!=request.getDislikedIngredientIds().size()) throw new BadRequestException("One or more disliked ingredients no longer exist.");
        }
        if(request.getPreferredCategories()!=null) pref.setPreferredCategories(clean(request.getPreferredCategories()));
        if(newAllergies!=null) { newAllergies.addAll(legacy(pref.getAllergies(),true)); pref.setAllergies(newAllergies); }
        if(newDiets!=null) { newDiets.addAll(legacy(pref.getDietaryRestrictions(),false)); pref.setDietaryRestrictions(newDiets); }
        if(dislikes!=null) pref.setDislikedIngredientRefs(dislikes);
        if(request.getPreferredMealGoals()!=null) pref.setPreferredMealGoals(new HashSet<>(request.getPreferredMealGoals()));
        return response(preferences.save(pref));
    }
    private Set<String> canonical(Set<String> values,boolean allergy) {
        var result=new TreeSet<String>();
        for(var value:values) {
            var parsed=recognized(value,allergy);
            if(parsed==null) throw new BadRequestException("Choose a supported "+(allergy?"avoidance":"dietary preference")+".");
            result.add(parsed);
        }
        return result;
    }
    private static Set<String> clean(Set<String> values) {
        return values.stream().filter(Objects::nonNull).map(String::trim).filter(s->!s.isEmpty()).collect(Collectors.toCollection(TreeSet::new));
    }
    public static String recognized(String value,boolean allergy) {
        if(value==null) return null;
        String normalized=value.trim().toUpperCase(Locale.ROOT).replace(' ','_').replace('-','_');
        if(allergy) normalized=switch(normalized) { case "MILK" -> "DAIRY";case "PEANUTS" -> "PEANUT";case "TREE_NUTS" -> "TREE_NUT";case "EGGS" -> "EGG";default -> normalized; };
        try { return allergy ? Allergen.valueOf(normalized).name() : DietaryPreference.valueOf(normalized).name(); }
        catch(IllegalArgumentException ex) { return null; }
    }
    private static Set<String> legacy(Set<String> values,boolean allergy) {
        return values.stream().filter(Objects::nonNull).filter(v->recognized(v,allergy)==null).collect(Collectors.toCollection(TreeSet::new));
    }
    private PreferencesResponse response(UserPreference pref) {
        var allergies=pref.getAllergies().stream().map(v->recognized(v,true)).filter(Objects::nonNull).collect(Collectors.toCollection(TreeSet::new));
        var diets=pref.getDietaryRestrictions().stream().map(v->recognized(v,false)).filter(Objects::nonNull).collect(Collectors.toCollection(TreeSet::new));
        var response=new PreferencesResponse(pref.getId(),new TreeSet<>(pref.getPreferredCategories()),allergies,diets,new TreeSet<>(pref.getDislikedIngredients()));
        response.setLegacyAllergies(legacy(pref.getAllergies(),true));response.setLegacyDietaryRestrictions(legacy(pref.getDietaryRestrictions(),false));
        response.setDislikedIngredientIds(pref.getDislikedIngredientRefs().stream().map(Ingredient::getId).collect(Collectors.toCollection(TreeSet::new)));
        response.setPreferredMealGoals(new TreeSet<>(pref.getPreferredMealGoals()));
        return response;
    }
}
