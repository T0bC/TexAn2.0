library(mvtnorm)
library(openxlsx)

set.seed(42)
n <- 500

# Group A: 3 sub-clusters
a1 <- rmvnorm(n = n, mean = c(-4, -4))
a2 <- rmvnorm(n = n, mean = c(0, 4))
a3 <- rmvnorm(n = n, mean = c(4, -4))

# Group B: 3 sub-clusters
b1 <- rmvnorm(n = n, mean = c(-4, 4))
b2 <- rmvnorm(n = n, mean = c(4, 4))
b3 <- rmvnorm(n = n, mean = c(0, 0))

# Group C: 3 sub-clusters
c1 <- rmvnorm(n = n, mean = c(-4, 0))
c2 <- rmvnorm(n = n, mean = c(0, -4))
c3 <- rmvnorm(n = n, mean = c(4, 0))

measurements <- rbind(a1, a2, a3, b1, b2, b3, c1, c2, c3)

train_data <- data.frame(
  GROUP = rep(c("group_a", "group_b", "group_c"), each = 3 * n),
  x1 = measurements[, 1],
  x2 = measurements[, 2]
)

write.xlsx(
  train_data,
  file.path("C:/Users/meissnerto/Desktop/TexAn2.0/data/test/mda_test.xlsx"),
  overwrite = TRUE
)

