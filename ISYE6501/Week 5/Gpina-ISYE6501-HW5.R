## 1. Setup ------------------------------------------------------------------

# 1.1 Load required libraries
library(MASS) # stepAIC
library(glmnet) # lasso / elastic net

# Install and load FrF2 with error handling
if (!require(FrF2, quietly = TRUE)) {
    cat("Installing FrF2 package...\n")
    install.packages("FrF2", dependencies = TRUE)
    library(FrF2)
}

# Check if FrF2 loaded successfully
if (!"FrF2" %in% loadedNamespaces()) {
    stop("FrF2 package failed to load. Please install manually.")
} else {
    cat("FrF2 package loaded successfully.\n")
}

# 1.2 Load data
crime <- read.table("/home/pinagm/dev/OMSA/ISYE6501/Week 5/uscrime.txt", header = TRUE) # nolint
head(crime)
str(crime)

# 1.3 Define response & predictors
response <- "Crime"
predictors <- setdiff(names(crime), response)
y <- crime[[response]]
x <- as.matrix(crime[, predictors])


## 2. Stepwise Regression Analysis ------------------------------------------

## 2.1 Full and Null Models
full_mod <- lm(Crime ~ ., data = crime)
null_mod <- lm(Crime ~ 1, data = crime)

## 2.2 Stepwise Methods
step_fwd <- stepAIC(null_mod,
    scope = list(lower = null_mod, upper = full_mod),
    direction = "forward", trace = FALSE
)
step_bwd <- stepAIC(full_mod, direction = "backward", trace = FALSE)
step_both <- stepAIC(null_mod,
    scope = list(lower = null_mod, upper = full_mod),
    direction = "both", trace = FALSE
)

## 2.3 Results Summary
stepwise_results <- data.frame(
    Method = c("Full", "Forward", "Backward", "Both"),
    Variables = c(
        length(coef(full_mod)) - 1,
        length(coef(step_fwd)) - 1,
        length(coef(step_bwd)) - 1,
        length(coef(step_both)) - 1
    ),
    AIC = round(c(AIC(full_mod), AIC(step_fwd), AIC(step_bwd), AIC(step_both)), 1), # nolint
    Adj_R2 = round(c(
        summary(full_mod)$adj.r.squared,
        summary(step_fwd)$adj.r.squared,
        summary(step_bwd)$adj.r.squared,
        summary(step_both)$adj.r.squared
    ), 3)
)

print(stepwise_results)

# Best model
best_idx <- which.min(stepwise_results$AIC[-1]) + 1
# Exclude full model from comparison
cat(
    "\nBest model:", stepwise_results$Method[best_idx],
    "| AIC:", stepwise_results$AIC[best_idx],
    "| Adj R²:", stepwise_results$Adj_R2[best_idx], "\n"
)

# Selected variables for best model
best_model <- list(step_fwd, step_bwd, step_both)[[best_idx - 1]]
cat("Variables:", paste(names(coef(best_model))[-1], collapse = ", "), "\n")


## 3. Lasso Regression (α = 1) ----------------------------------------------

## 3.1 Scale predictors and fit CV Lasso
x_scaled <- scale(x)
set.seed(123)
cv_lasso <- cv.glmnet(x_scaled, y, alpha = 1, nfolds = 10)

## 3.2 Results
best_lambda <- cv_lasso$lambda.min
lasso_mod <- glmnet(x_scaled, y, alpha = 1, lambda = best_lambda)

# Extract non-zero coefficients
lasso_coefs <- coef(lasso_mod)
selected_vars <- rownames(lasso_coefs)[lasso_coefs[, 1] != 0][-1] # Exclude intercept

cat("Lasso Results:\n")
cat("Optimal λ:", round(best_lambda, 4), "\n")
cat("Variables selected:", length(selected_vars), "\n")
cat("Selected variables:", paste(selected_vars, collapse = ", "), "\n")

# Optional: Show plot
plot(cv_lasso, main = "Lasso Cross-Validation")

## 4. Elastic Net Regression ------------------------------------------------

## 4.1 Grid Search over α
alpha_vals <- seq(0, 1, by = 0.1)
set.seed(123)

# Find best alpha-lambda combination
best_cvm <- Inf
best_alpha <- NA
best_lambda <- NA

for (a in alpha_vals) {
    cv <- cv.glmnet(x_scaled, y, alpha = a, nfolds = 10)
    if (min(cv$cvm) < best_cvm) {
        best_cvm <- min(cv$cvm)
        best_alpha <- a
        best_lambda <- cv$lambda.min
    }
}

## 4.2 Final Elastic Net Fit
enet_mod <- glmnet(x_scaled, y, alpha = best_alpha, lambda = best_lambda)
enet_coefs <- coef(enet_mod)
selected_vars <- rownames(enet_coefs)[enet_coefs[, 1] != 0][-1] # Exclude intercept

cat("Elastic Net Results:\n")
cat("Best α:", best_alpha, "| Best λ:", round(best_lambda, 4), "\n")
cat("Variables selected:", length(selected_vars), "\n")
cat("Selected variables:", paste(selected_vars, collapse = ", "), "\n")


# Define 10 yes/no factors
factors <- paste0("F", 1:10)

# Generate a 2^(10-6) fractional factorial design (16 runs)
design <- FrF2(nruns = 16, nfactors = 10, factor.names = factors)

# Display the design (1 = include feature, -1 = exclude feature)
print(design)
