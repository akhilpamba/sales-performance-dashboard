# %%
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from statsmodels.tsa.seasonal import seasonal_decompose
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from sklearn.metrics import mean_absolute_percentage_error

# %%
df = pd.read_csv('data/monthly_sales.csv')
df.head()

# %%
df['month'] = pd.to_datetime(df['month'])
df = df.sort_values('month').set_index('month')
df.shape

# %%
# plot raw revenue
plt.figure(figsize=(12, 4))
plt.plot(df.index, df['revenue'])
plt.title('Monthly Revenue')
plt.ylabel('Revenue ($)')
plt.tight_layout()
plt.show()

# clear upward trend, looks like some seasonality too

# %%
# decompose to check
decomp = seasonal_decompose(df['revenue'], model='additive', period=12)

fig, axes = plt.subplots(4, 1, figsize=(12, 8))
decomp.observed.plot(ax=axes[0], title='Observed')
decomp.trend.plot(ax=axes[1], title='Trend')
decomp.seasonal.plot(ax=axes[2], title='Seasonal')
decomp.resid.plot(ax=axes[3], title='Residual')
plt.tight_layout()
plt.savefig('plots/decomposition.png', dpi=150)
plt.show()

# %%
# Q4 seasonality is visible - makes sense for retail
# will use Holt-Winters to capture both trend and seasonality

# train/test split - hold out last 6 months for validation
train = df['revenue'][:-6]
test = df['revenue'][-6:]

print(f"Train: {len(train)} months")
print(f"Test: {len(test)} months")

# %%
# Holt-Winters with additive seasonality
model = ExponentialSmoothing(
    train,
    trend='add',
    seasonal='add',
    seasonal_periods=12
)
fitted = model.fit(optimized=True)

# %%
# forecast 6 months
forecast = fitted.forecast(6)

# compare to test
mape = mean_absolute_percentage_error(test, forecast)
accuracy = round((1 - mape) * 100, 1)
print(f"MAPE: {round(mape * 100, 1)}%")
print(f"Forecast Accuracy: {accuracy}%")

# %%
# 93% accuracy - good

# plot
plt.figure(figsize=(12, 5))
plt.plot(train.index, train, label='Train', color='steelblue')
plt.plot(test.index, test, label='Actual (holdout)', color='green')
plt.plot(forecast.index, forecast, label='Forecast', color='orange', linestyle='--')
plt.title('Revenue Forecast vs Actual (6-Month Holdout)')
plt.ylabel('Revenue ($)')
plt.legend()
plt.tight_layout()
plt.savefig('plots/forecast_vs_actual.png', dpi=150)
plt.show()

# %%
# now refit on full dataset and forecast next 6 months
full_model = ExponentialSmoothing(
    df['revenue'],
    trend='add',
    seasonal='add',
    seasonal_periods=12
).fit(optimized=True)

next_6 = full_model.forecast(6)

# generate future date index
last_date = df.index[-1]
future_dates = pd.date_range(start=last_date + pd.DateOffset(months=1), periods=6, freq='MS')
forecast_df = pd.DataFrame({'month': future_dates, 'forecasted_revenue': next_6.values})

print(forecast_df)

# %%
forecast_df.to_csv('data/revenue_forecast_6mo.csv', index=False)

# %%
# quick sanity check - are the forecast numbers reasonable?
print("Avg last 6 months actual:", round(df['revenue'][-6:].mean(), 0))
print("Avg next 6 months forecast:", round(next_6.mean(), 0))
# ~8% projected growth - consistent with the trend line, looks right
