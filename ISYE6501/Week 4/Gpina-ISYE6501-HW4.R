# Load required packages
library(tidyverse)
library(rpart)
library(rpart.plot)
library(randomForest)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # #  Question 9.1

# Read in the dataset
crime_data <- read.table("ISYE6501/Week 4/uscrime.txt", header = TRUE)

# Preview the first few rows
head(crime_data)

# Remove the response variable (Crime) for PCA
predictors <- crime_data %>% select(-Crime)

# Run PCA with scaling
pca_result <- prcomp(predictors, scale. = TRUE)

# Scree plot to decide how many components to retain
plot(pca_result, type = "l", main = "Scree Plot")

# Show cumulative proportion of variance
summary(pca_result)

# Separate predictor variables for PCA analysis
predictors <- crime_data %>% select(-Crime)

# Perform PCA with standardization
pca_result <- prcomp(predictors, scale. = TRUE)

# Visualize variance explained by each component
plot(pca_result, type = "l", main = "Scree Plot - Variance by Principal Component")

# Get detailed summary of variance explained
summary(pca_result)

# Quick check of results
cat("Total number of components:", length(pca_result$sdev), "\n")
cat(
    "Variance explained by first 3 components:",
    round(sum(pca_result$sdev[1:3]^2) / sum(pca_result$sdev^2) * 100, 1),
    "%\n"
)

# Define number of principal components to keep
var_explained <- pca_result$sdev^2 / sum(pca_result$sdev^2)
cum_var_explained <- cumsum(var_explained)
num_pc_ideal <- which(cum_var_explained >= 0.80)[1] # Ideal number of components based on 80% variance
cat("Ideal number of components for 80% variance:", num_pc_ideal, "\n")

# Transform PCA coefficients back to original scale
beta_pca <- coef(model_pca)[-1] # Coefficients from the PCA model (excluding intercept)
num_pc_model <- length(beta_pca) # Actual number of components used in model_pca
cat("Number of components used in model_pca:", num_pc_model, "\n")

# Extract loadings for the number of components actually used in model_pca
loadings <- pca_result$rotation[, 1:num_pc_model]
scales <- apply(predictors, 2, sd)

# Check dimensions to confirm they're compatible
print(paste("Dimensions of loadings:", paste(dim(loadings), collapse = "x")))
print(paste("Length of beta_pca:", length(beta_pca)))

# Convert beta_pca to a column vector explicitly
beta_pca_matrix <- matrix(beta_pca, ncol = 1)
print(paste("Dimensions of beta_pca_matrix:", paste(dim(beta_pca_matrix), collapse = "x")))

# Proper matrix multiplication
beta_original <- loadings %*% beta_pca_matrix

# Adjust intercept for scaling
intercept <- coef(model_pca)[1] -
    sum(colMeans(predictors) /
        scales * beta_original[1:length(scales)]) # Ensure beta_original aligns with scales if necessary

# Create final coefficient vector
# Ensure beta_original is correctly scaled. beta_original are coefficients for scaled original predictors.
# To get coefficients for unscaled original predictors, they need to be divided by 'scales'.
coeffs_original_space <- c(intercept, beta_original / scales)
names(coeffs_original_space) <- c("(Intercept)", colnames(predictors))


# Make predictions with new data using the fitted model
new_city <- data.frame(
    M      = 14.0,
    So     = 0,
    Ed     = 10.0,
    Po1    = 12.0,
    Po2    = 15.5,
    LF     = 0.640,
    M.F    = 94.0,
    Pop    = 150,
    NW     = 1.1,
    U1     = 0.120,
    U2     = 3.6,
    Wealth = 3200,
    Ineq   = 20.1,
    Prob   = 0.04,
    Time   = 39.0
)

# Method 1: Direct prediction using the original model
prediction_direct <- predict(model_original, newdata = new_city)
cat("Direct prediction using original model:", round(prediction_direct, 1), "\n")

# Method 2: Manual calculation using coefficients
coeffs <- coefficients(model_original)
prediction_manual <- coeffs[1] + sum(coeffs[-1] * as.numeric(new_city))
cat("Manual calculation using coefficients:", round(prediction_manual, 1), "\n")

# For PCA model prediction - transform new data to PCA space
new_city_scaled <- scale(new_city,
    center = colMeans(predictors),
    scale = apply(predictors, 2, sd)
)

new_city_pca <- new_city_scaled %*% pca_result$rotation[, 1:num_pc]
prediction_pca <- predict(model_pca, data.frame(new_city_pca))
cat("PCA model prediction:", round(prediction_pca, 1), "\n")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # Question 10.1

# Load the data
crime_data <- read.table("ISYE6501/Week 4/uscrime.txt", header = TRUE)

# Check structure
str(crime_data)

# Fit tree model
tree_model <- rpart(Crime ~ ., data = crime_data, method = "anova")

# Plot tree
rpart.plot(tree_model, main = "Crime Prediction Tree")

# Get summary
summary(tree_model)


# Build random forest
set.seed(123)
rf_model <- randomForest(Crime ~ .,
    data = crime_data,
    ntree = 500, importance = TRUE
)

# Compare variable importance
par(mfrow = c(1, 2))
varImpPlot(rf_model, main = "RF Importance")
barplot(sort(tree_model$variable.importance, decreasing = TRUE),
    main = "Tree Importance", las = 2, cex.names = 0.7
)
par(mfrow = c(1, 1))

# Predict using tree
tree_prediction <- predict(tree_model, newdata = new_city)

# Compare predictions
cat("\nModel Comparison:\n")
cat("Linear Regression:", round(prediction_direct, 1), "\n")
cat("Random Forest:", round(predict(rf_model, newdata = new_city), 1), "\n")
cat("Decision Tree:", round(tree_prediction, 1), "\n")
cat("PCA Regression:", round(prediction_pca, 1), "\n")

# Trace tree path
cat("\nTree path for prediction:\n")
cat("- Po1 =", new_city$Po1, "> 7.65 → Node 3 (mean: 1130.75)\n")
cat("- NW =", new_city$NW, "< 7.65 → Node 6 (mean: 886.9)\n")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # #  Question 10.3

# Define column names from dataset documentation
column_names <- c(
    "Status", "Duration", "CreditHistory", "Purpose", "CreditAmount",
    "Savings", "Employment", "InstallmentRate", "Personal", "Debtors",
    "ResidenceTime", "Property", "Age", "InstallmentPlans", "Housing",
    "ExistingCredits", "Job", "LiablePeople", "Telephone", "ForeignWorker", "CreditRisk"
)

# Read dataset
german_data <- read.table("ISYE6501/Week 4/germancredit.txt", header = FALSE)
colnames(german_data) <- column_names

# Convert CreditRisk: 1 = good (original 1), 0 = bad (original 2)
german_data$CreditRisk <- ifelse(german_data$CreditRisk == 1, 1, 0)

# View structure
str(german_data)

# Fit logistic regression model on full data
logit_model <- glm(CreditRisk ~ ., data = german_data, family = binomial(link = "logit"))

# View model summary
summary(logit_model)

# Predict probabilities
predicted_probs <- predict(logit_model, type = "response")

# Load pROC package for ROC curve
library(pROC)

# Compute and plot ROC
roc_result <- roc(german_data$CreditRisk, predicted_probs)
plot(roc_result, main = "ROC Curve")
auc(roc_result)

# Calculate predicted probabilities from logistic model
credit_probs <- predict(logit_model, type = "response")

# Create ROC object
roc_obj <- roc(german_data$CreditRisk, credit_probs)

# Find optimal threshold (maximizing sensitivity + specificity)
optimal_coords <- coords(roc_obj, "best", best.method = "youden")
optimal_threshold <- optimal_coords$threshold

# Display results
cat("Optimal Threshold Analysis:\n")
cat("------------------------\n")
cat("Optimal threshold:", round(optimal_threshold, 3), "\n")
cat("Sensitivity at threshold:", round(optimal_coords$sensitivity, 3), "\n")
cat("Specificity at threshold:", round(optimal_coords$specificity, 3), "\n")
cat("AUC:", round(auc(roc_obj), 3), "\n\n")

# Create confusion matrix at optimal threshold
predicted_classes <- ifelse(credit_probs >= optimal_threshold, 1, 0)
conf_matrix <- table(Actual = german_data$CreditRisk, Predicted = predicted_classes)

# Display confusion matrix
cat("Confusion Matrix at Optimal Threshold:\n")
print(conf_matrix)
cat("\nAccuracy:", round(sum(diag(conf_matrix)) / sum(conf_matrix), 3))
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
