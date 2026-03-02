print("XXXXXXXXXXXXXXX")

cat('Checking file content at line 276-278:\n') 
lines <- readLines('C:/Users/meissnerto/Desktop/TexAn2.0/app/logic/statistics/nonparametric_tests.R')
cat(paste(lines[276:278], collapse='\n'))

# Force box module reload
if (exists("nonparametric_tests")) {
  box::unload(nonparametric_tests)
}
box::use(app/logic/statistics/nonparametric_tests)

# Test with unbalanced data to trigger validation
df <- expand.grid(
  GROUP = c("A", "B", "C"), 
  TREATMENT = c("X", "Y"), 
  stringsAsFactors = FALSE
)
df <- df[rep(1:nrow(df), each = c(2, 5, 5, 5, 5, 5)), ]  # Unbalanced: 2 vs 5
df$measure <- rnorm(nrow(df))
cat("Data structure:\n")
print(table(df$GROUP, df$TREATMENT))

cat("\nRunning ART test...\n")
result <- nonparametric_tests$perform_art2way(df = df, x_axis = c("GROUP", "TREATMENT"), measure_col = "measure")
print(result)