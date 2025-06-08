library(tidyverse) # for data manipulation and plotting
library(lubridate) # for date parsing
library(forecast) # for ets() exponential smoothing
temps_raw <- read.delim("temps.txt", header = TRUE, stringsAsFactors = FALSE)

# Inspecting first few rows
head(temps_raw)

# Reshaping data & creating Date column
temps_long <- temps_raw %>%
    pivot_longer(
        cols = -DAY, # nolint
        names_to = "year",
        values_to = "high_temp"
    ) %>%
    mutate(
        # Remove the 'X' prefix before converting to integer
        year = as.integer(gsub("X", "", year)),
        # create a "day_month" string by combining DAY and year
        day_month = paste0(DAY, "-", year),
        # parse it into a Date, e.g. "1-Jul-1996"
        date = dmy(day_month)
    ) %>%
    select(date, year, high_temp) %>%
    arrange(date)

# Check that parsing worked
head(temps_long)
tail(temps_long)

# defining a function to fit ETS and return the fitted values per day
fit_ets_for_year <- function(df_year) {
    # df_year is a tibble with date, year, high_temp
    # create a ts object of length = number of days (should be ~123)
    y <- ts(df_year$high_temp, frequency = 1)
    # fit ETS with additive error, additive trend, no seasonal (AAN)
    fit <- ets(y, model = "AAN", damped = FALSE)
    # obtain the “in‐sample” fitted (smoothed) values
    fitted_vals <- as.numeric(fitted(fit))
    tibble(
        date = df_year$date,
        year = df_year$year,
        high_temp = df_year$high_temp,
        smooth_temp = fitted_vals
    )
}

# applying fit_ets_for_year to each year
temps_smoothed <- temps_long %>%
    group_by(year) %>%
    group_split() %>%
    map(~ fit_ets_for_year(.x)) %>%
    bind_rows() %>%
    ungroup()

# Quick check: what does it look like?
head(temps_smoothed)


# computing end‐of‐summer date per year
threshold <- 80

end_of_summer <- temps_smoothed %>%
    filter(smooth_temp > threshold) %>%
    group_by(year) %>%
    summarize(end_of_summer_date = max(date)) %>%
    ungroup()

end_of_summer


# viewing the results in a table
end_of_summer %>% arrange(year)


# adding a “day_of_year” column
end_of_summer <- end_of_summer %>%
    mutate(
        day_of_year = yday(end_of_summer_date)
    )

# Plot DOY vs. year, plus a linear trend line
ggplot(end_of_summer, aes(x = year, y = day_of_year)) +
    geom_point(size = 2) +
    geom_smooth(method = "lm", se = TRUE, color = "blue") +
    scale_y_continuous(
        breaks = c(180, 200, 220, 240, 260, 280, 300, 320),
        labels = function(x) paste0(x)
    ) +
    labs(
        title = "End of Summer (Smoothed > 80°F) in Atlanta, 1996–2015",
        x = "Year",
        y = "Day of Year (DOY)",
        caption = "Last date (July–Oct) where ETS‐smoothed high_temp > 80°F"
    ) +
    theme_minimal(base_size = 12)


# fitting lm(day_of_year ~ year) and show summary
lm_fit <- lm(day_of_year ~ year, data = end_of_summer)
summary(lm_fit)


# visualizing one example year
eos_date_2015 <- end_of_summer %>%
    filter(year == year_to_plot) %>%
    pull(end_of_summer_date)

temps_smoothed %>%
    filter(year == year_to_plot) %>%
    ggplot(aes(x = date)) +
    geom_line(aes(y = high_temp),
        color = "gray40", linewidth = 0.8,
        alpha = 0.7
    ) +
    geom_line(aes(y = smooth_temp), color = "firebrick", linewidth = 1) +
    geom_vline(
        xintercept = eos_date_2015, linetype = "dashed",
        color = "blue"
    ) +
    labs(
        title = paste0(
            "Year ", year_to_plot,
            ": Raw vs. ETS‐Smoothed Highs"
        ),
        subtitle = paste0(
            "End of Summer (Smoothed > 80°F) = ",
            eos_date_2015
        ),
        x = "Date",
        y = "Temperature (°F)",
        caption = paste0(
            "Gray = raw daily highs; Red = ETS fitted; ",
            "Blue dashed = end‐of‐summer"
        )
    ) +
    theme_minimal(base_size = 12)
