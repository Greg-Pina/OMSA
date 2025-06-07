crime <- read.table("uscrime.txt", header = TRUE)
# Inspecting the first few rows
head(crime)

# Fit a linear regression model predicting Crime from all 15 predictors
model <- lm(
    Crime ~ M + So + Ed + Po1 + Po2 + LF + M.F + Pop + NW + U1 +
        U2 + Wealth + Ineq + Prob + Time,
    data = crime
)

# View the summary of the fitted model
summary(model)

# Creating new data frame for the city’s predictors
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

# Extract model coefficients
coefficients(model)

# Model quality metrics
cat("Model Quality of Fit:\n")
cat("Multiple R-squared:", summary(model)$r.squared, "\n")
cat("Adjusted R-squared:", summary(model)$adj.r.squared, "\n")
cat("Residual standard error:", summary(model)$sigma, "\n")
cat(
    "F-statistic:", summary(model)$fstatistic[1],
    "on", summary(model)$fstatistic[2], "and", summary(model)$fstatistic[3],
    "DF\n"
)
cat("p-value:", pf(summary(model)$fstatistic[1],
    summary(model)$fstatistic[2],
    summary(model)$fstatistic[3],
    lower.tail = FALSE
), "\n")
