package com.akletna.backend.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.*;

@Entity
@Table(name="grocery_contributions",uniqueConstraints=@UniqueConstraint(name="uq_grocery_source_context",columnNames={"grocery_list_id","source_key"}))
public class GroceryContribution {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="grocery_list_id",nullable=false) private GroceryList groceryList;
    @Column(nullable=false,length=30) private String source;
    @Column(name="source_key",nullable=false,length=100) private String sourceKey;
    @Column(nullable=false) private String sourceName;
    private Long recipeId; // Historical scalar: source deletion must not delete groceries.
    private Integer servings;
    @Column(nullable=false) private LocalDateTime createdAt;
    @ElementCollection
    @CollectionTable(name="grocery_contribution_lines",joinColumns=@JoinColumn(name="contribution_id"))
    @OrderColumn(name="line_index")
    private List<GroceryContributionLine> lines=new ArrayList<>();
    protected GroceryContribution() {}
    public GroceryContribution(GroceryList list,String source,String key,String name,Long recipeId,Integer servings,List<GroceryContributionLine> lines) {
        groceryList=list;this.source=source;sourceKey=key;sourceName=name;this.recipeId=recipeId;this.servings=servings;
        createdAt=LocalDateTime.now();this.lines.addAll(lines);
    }
    public Long getId(){return id;}
    public String getSource(){return source;}
    public String getSourceKey(){return sourceKey;}
    public String getSourceName(){return sourceName;}
    public Long getRecipeId(){return recipeId;}
    public Integer getServings(){return servings;}
    public LocalDateTime getCreatedAt(){return createdAt;}
    public List<GroceryContributionLine> getLines(){return Collections.unmodifiableList(lines);}
    public void replacePlannedLines(List<GroceryContributionLine> values) {
        if(!"PLANNED_MEAL".equals(source)) throw new IllegalStateException("Only planned requirements are regenerated.");
        lines.clear();lines.addAll(values);
    }
}
