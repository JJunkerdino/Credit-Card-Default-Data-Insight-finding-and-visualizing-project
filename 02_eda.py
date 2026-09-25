from pathlib import Path

import duckdb
import matplotlib.pyplot as plt
import seaborn as sns

from sql_utils import run_sql_file

ROOT = Path(__file__).parent
FIG_DIR = ROOT / "outputs" / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)

con = duckdb.connect(str(ROOT / "data" / "default.duckdb"), read_only=True)
results = run_sql_file(con, ROOT / "sql" / "02_eda.sql")
df = con.sql("SELECT * FROM default_clean").df()
con.close()

df["default"] = df["default_flag"].map({0: "No", 1: "Yes"})
df["student"] = df["is_student"].map({0: "No", 1: "Yes"})

sns.set_theme(style="whitegrid")
PALETTE = {"No": "#4C72B0", "Yes": "#DD5555"}


def save(fig, name):
    fig.tight_layout()
    fig.savefig(FIG_DIR / name, dpi=150)
    plt.close(fig)
    print(f"Saved outputs/figures/{name}")


print()

# 1. Target imbalance
fig, ax = plt.subplots(figsize=(5, 4))
sns.countplot(data=df, x="default", hue="default", palette=PALETTE, legend=False, ax=ax)
for container in ax.containers:
    ax.bar_label(container, labels=[f"{v:,.0f} ({v / len(df):.1%})" for v in container.datavalues])
ax.margins(y=0.12)
ax.set_title("Default: Yes vs No (imbalanced)")
save(fig, "01_target_distribution.png")

# 2. Distributions by default (density so the small 'Yes' group is visible)
fig, axes = plt.subplots(1, 2, figsize=(11, 4))
for ax, col in zip(axes, ["balance", "income"]):
    sns.histplot(data=df, x=col, hue="default", palette=PALETTE, stat="density",
                 common_norm=False, element="step", bins=40, ax=ax)
    ax.set_title(f"{col.title()} distribution by default")
save(fig, "02_distributions_by_default.png")

# 3. Boxplots by default and by student
fig, axes = plt.subplots(2, 2, figsize=(10, 8))
for row, group in enumerate(["default", "student"]):
    for col_idx, col in enumerate(["balance", "income"]):
        ax = axes[row, col_idx]
        sns.boxplot(data=df, x=group, y=col, hue=group, legend=False, ax=ax,
                    palette=PALETTE if group == "default" else "Set2")
        ax.set_title(f"{col.title()} by {group}")
save(fig, "03_boxplots.png")

# 4. Balance vs income, defaulters drawn on top
fig, ax = plt.subplots(figsize=(8, 6))
sns.scatterplot(data=df.sort_values("default_flag"), x="balance", y="income", hue="default",
                palette=PALETTE, alpha=0.5, s=12, edgecolor=None, ax=ax)
ax.set_title("Balance vs income (red = defaulted)")
save(fig, "04_scatter_balance_income.png")

# 5. Default rate by balance band
band = results["default_rate_by_balance_band"]
fig, ax = plt.subplots(figsize=(8, 4))
labels = [f"{a:,}-{b:,}" for a, b in zip(band["balance_from"], band["balance_to"])]
bars = ax.bar(labels, band["default_rate_pct"], color="#DD5555")
ax.bar_label(bars, labels=[f"{v:.1f}%" for v in band["default_rate_pct"]])
ax.set(title="Default rate by balance band", xlabel="Balance", ylabel="Default rate (%)")
save(fig, "05_default_rate_by_balance.png")

# 6. Student paradox: same balance band, students default less
paradox = results["student_paradox"].copy()
# Rates from fewer than 10 people are noise (e.g. 3 students at 2500+)
paradox.loc[paradox["n_non_student"] < 10, "non_student_rate_pct"] = None
paradox.loc[paradox["n_student"] < 10, "student_rate_pct"] = None
fig, ax = plt.subplots(figsize=(8, 4))
ax.plot(paradox["balance_from"], paradox["non_student_rate_pct"], marker="o", label="Non-student")
ax.plot(paradox["balance_from"], paradox["student_rate_pct"], marker="o", label="Student")
ax.set(title="Student paradox: at the same balance, students default less",
       xlabel="Balance band start", ylabel="Default rate (%)")
ax.legend()
save(fig, "06_student_paradox.png")

# 7. Correlation heatmap
fig, ax = plt.subplots(figsize=(5, 4))
corr = df[["default_flag", "balance", "income", "is_student"]].corr()
sns.heatmap(corr, annot=True, fmt=".2f", cmap="coolwarm", vmin=-1, vmax=1, ax=ax)
ax.set_title("Correlation matrix")
save(fig, "07_correlation_heatmap.png")
