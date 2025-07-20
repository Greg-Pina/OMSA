import pandas as pd
import gurobipy as gp
from gurobipy import GRB

# Load Excel file
xls = pd.read_excel("diet.xls", sheet_name=None)
foods_df = xls['Sheet1']
nutrients_df = xls['Sheet2']
foods_df.head()

# Create model
model = gp.Model("BasicDiet")

# Filter out constraint rows and get clean food data
foods_df_clean = foods_df.dropna(subset=['Foods'])
foods = foods_df_clean['Foods']
cost = dict(zip(foods, foods_df_clean['Price/ Serving']))
food_vars = model.addVars(foods, name="Servings", lb=0)

# Objective: minimize cost
model.setObjective(gp.quicksum(cost[f] * food_vars[f] for f in foods), GRB.MINIMIZE)

# Extract constraint data from the foods DataFrame
# Row 65 has minimum values, Row 66 has maximum values
min_constraints = foods_df.iloc[65]  # Minimum daily intake row
max_constraints = foods_df.iloc[66]  # Maximum daily intake row

# Get nutrient column names (excluding non-nutrient columns)
nutrient_cols = [col for col in foods_df.columns if col not in ['Foods', 'Price/ Serving', 'Serving Size']]

# Add nutrition constraints
for nutrient in nutrient_cols:
    min_val = min_constraints[nutrient]
    max_val = max_constraints[nutrient]
    
    # Create constraint coefficients
    coef = dict(zip(foods, foods_df_clean[nutrient]))
    
    # Add minimum constraint
    model.addConstr(gp.quicksum(coef[f] * food_vars[f] for f in foods) >= min_val, f"{nutrient}_min")
    
    # Add maximum constraint
    model.addConstr(gp.quicksum(coef[f] * food_vars[f] for f in foods) <= max_val, f"{nutrient}_max")

model.optimize()

# Print results
if model.status == GRB.OPTIMAL:
    print(f"Optimal cost: ${model.objVal:.2f}")
    print("\nOptimal diet:")
    for f in foods:
        if food_vars[f].x > 0.001:  # Only show foods with significant quantities
            print(f"{f}: {food_vars[f].x:.3f} servings")
            
            
if model.status == GRB.OPTIMAL:
    print(f"Optimal Cost: ${model.ObjVal:.2f}")
    for f in foods:
        if food_vars[f].X > 1e-4:
            print(f"{f}: {food_vars[f].X:.2f} servings")
            
            
model2 = gp.Model("ExtendedDiet")

servings = model2.addVars(foods, name="Servings", lb=0)
chosen = model2.addVars(foods, vtype=GRB.BINARY, name="Chosen")
model2.setObjective(gp.quicksum(cost[f] * servings[f] for f in foods), GRB.MINIMIZE)

# Extract constraint data from foods DataFrame
min_constraints = foods_df.iloc[65]
max_constraints = foods_df.iloc[66]
nutrient_cols = [col for col in foods_df.columns if col not in ['Foods', 'Price/ Serving', 'Serving Size']]

# Nutrition constraints
for nutrient in nutrient_cols:
    min_val = min_constraints[nutrient]
    max_val = max_constraints[nutrient]
    coef = dict(zip(foods, foods_df_clean[nutrient]))
    model2.addConstr(gp.quicksum(coef[f] * servings[f] for f in foods) >= min_val, f"{nutrient}_min")
    model2.addConstr(gp.quicksum(coef[f] * servings[f] for f in foods) <= max_val, f"{nutrient}_max")

# Linking constraints (minimum 0.1 serving if chosen, food-specific upper bounds)
celery_max = 30
lettuce_max = 30
default_max = 40
for f in foods:
    model2.addConstr(servings[f] >= 0.1 * chosen[f], f"{f}_minlink")
    if f == "Celery, Raw":
        model2.addConstr(servings[f] <= celery_max * chosen[f], f"{f}_maxlink")
    elif f == "Lettuce,Iceberg,Raw":
        model2.addConstr(servings[f] <= lettuce_max * chosen[f], f"{f}_maxlink")
    else:
        model2.addConstr(servings[f] <= default_max * chosen[f], f"{f}_maxlink")

# Celery/Broccoli constraint (at most one)
celery_food = "Celery, Raw"
broccoli_food = "Frozen Broccoli"
if celery_food in foods.values and broccoli_food in foods.values:
    model2.addConstr(chosen[celery_food] + chosen[broccoli_food] <= 1, "celery_broccoli_limit")

# Protein variety constraint (at least 3 sources)
protein_keywords = ["beef", "chicken", "egg", "ham", "fish", "turkey", "pork"]
protein_sources = [f for f in foods if any(p in f.lower() for p in protein_keywords)]
print(f"Found protein sources: {protein_sources}")

if len(protein_sources) >= 3:
    model2.addConstr(gp.quicksum(chosen[f] for f in protein_sources) >= 3, "protein_variety")
else:
    print("Warning: Less than 3 protein sources found. Relaxing constraint.")

# Solver parameters
model2.setParam('OutputFlag', 1)
model2.setParam('MIPGap', 0.01)
model2.setParam('TimeLimit', 300)

model2.optimize()

# Enhanced result reporting
if model2.status == GRB.OPTIMAL:
    print(f"\nOptimal cost: ${model2.objVal:.2f}")
    print(f"Number of foods chosen: {sum(1 for f in foods if chosen[f].x > 0.5)}")
    print("\nOptimal diet:")
    total_servings = 0
    for f in foods:
        if chosen[f].x > 0.5:
            servings_val = servings[f].x
            total_servings += servings_val
            print(f"{f}: {servings_val:.3f} servings")
    print(f"\nTotal servings per day: {total_servings:.1f}")

elif model2.status == GRB.INFEASIBLE:
    print("Model is infeasible")
    model2.computeIIS()
    print("Conflicting constraints:")
    for c in model2.getConstrs():
        if c.IISConstr:
            print(f"  {c.constrName}")
            
            
if model2.status == GRB.OPTIMAL:
    print(f"Optimal Cost (Extended): ${model2.ObjVal:.2f}")
    for f in foods:
        if servings[f].X > 1e-4:
            print(f"{f}: {servings[f].X:.2f} servings")                                    