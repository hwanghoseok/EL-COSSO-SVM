#%%
install.packages("languageserver")
install.packages("mlbench")
install.packages("httpgd")
library(mlbench)
library(MASS)
#%%


sim_gen = function(n, p, seed = NULL, type = c("linear", "poly", "cosso", "neuralnet"))
{
    call = match.call()
    type = match.arg(type)

    if (!is.null(seed)) {
    set.seed(seed)
}

if (type == "cosso") {
    X = matrix(rnorm(n * p), n, p)
    
    g1 = function(x) {x}
    g2 = function(x) {(2 * x - 1)^2}
    # g3 = function(x) {sin(2 * pi * x) / (2 - sin(2 * pi * x))}
    # g4 = function(x) {0.1 * sin(2 * pi * x) + 0.2 * cos(2 * pi * x) + 0.3 * sin(2 * pi * x)^2 + 0.4 * cos(2 * pi * x)^3 + 0.5 * sin(2 * pi * x)^3}
    
    lr1 = 1.1 * g1(X[, 1]) + 1.6 * g2(X[, 2]) - 2.2 #+ 1 * g3(X[, 3]) - 6 * g4(X[, 4])
    lr2 = 3.3 * g1(X[, 1]) + 1.5 * g2(X[, 2]) - 2.0 #- 3.5 * g3(X[, 3]) - 4.5 * g4(X[, 4])
    
    const = (1 + exp(lr1) + exp(lr2))
    prob1 = exp(lr1) / const
    prob2 = exp(lr2) / const
    prob3 = 1 / const
    probs = cbind(prob1, prob2, prob3)
    
    y = apply(probs, 1, function(prob) {sample(1:3, 1, TRUE, prob)})
    
    out = list()
    out$x = X
    out$y = y
    out$true = rep(c(1, 0), c(2, p - 2))
}

if (type == "linear") {
    dat = mlbench.2dnormals(n = n, cl = 3, sd = 1)
    X_true = dat$x
    r = ncol(X_true)
    y = dat$classes
    X_noise = matrix(rnorm(n * (p - r), sd = 1), nrow = n, ncol = p - r)
    X = cbind(X_true, X_noise)
    out = list()
    out$x = X
    out$y = y
    out$true = rep(c(1, 0), c(r, p - r)) # 1이면 true값, 0이면 noise
}

if (type == "poly") {
    r = 2
    X_tmp = matrix(rnorm(n * r, 0, 0.8), n, r)
    x1 = X_tmp[, 1]; x2 = X_tmp[, 2]
    c = 1
    X_kern = data.matrix(data.frame(x1^3, x2^3, sqrt(3) * x1^2 * x2, sqrt(3) * x1 * x2^2, 
    sqrt(3 * c) * x1^2, sqrt(3 * c) * x2^2, sqrt(6 * c) * x1 * x2, 
    sqrt(3) * c * x1, sqrt(3) * c * x2, sqrt(c^3)))
    beta1 = c(3, -2, 3.5, -3.5, 5.5, -4.5, 3, 0, -2, 0)
    beta2 = c(3, -3, 2.5, -2.5, 1, -1, 0, -2, -2, 0)
    beta3 = beta1 - beta2
    lr = X_kern %*% cbind(beta1, beta2, beta3)
    
    probs = exp(lr - as.vector(HTLR:::log_sum_exp(lr)))
    y = apply(probs, 1, function(prob) {
    sample(1:3, 1, TRUE, prob)})
    X_noise = matrix(rnorm(n * (p - r)), n, (p - r))
    X = cbind(X_tmp, X_noise)
    out = list()
    out$x = X
    out$y = y
    out$true = rep(c(1, 0), c(r, p -r)) 
}

if (type == "neuralnet") {
    r = 2
    X_tmp = matrix(rnorm(n * r, 0, 2.0), n, r)
    X_tmp = cbind(X_tmp, X_tmp[, 1] * X_tmp[, 2])
    sigmoid = function(x) {
    return(1 / (1 + exp(-x)))
    }
    
    LeLU = function(x) {
    return(pmax(0, x))
    }
    
    node = c(4, 3, 2)
    # beta_mat1 = matrix(c(3.5, 0.5, -3, 1.3, 3.2, -4.2, -1.5, 5.5, -3, 2.3, -3, 1), r)
    beta_mat1 = matrix(c(3.5, 1.3, -1.5, 2.3,0.5, 3.2, 5.5, -3.0,-3.0, -4.2, -3.0, -1.0),nrow = 3, byrow = TRUE)
    
    node1_mat = drop(X_tmp %*% beta_mat1) + 1
    layer1 = matrix(sigmoid(node1_mat), nrow = n, ncol = node[1])
    
    # beta_mat2 = matrix(c(3.5, 1.2, -2.7, -3, 
    #                     -2.5, 2, 1, 2,
    #                      1.5, -3, 2, 1), node[1], node[2])
    beta_mat2 = matrix(c(2.8, -2.5, -1.5,1.2, -2.0, -3.0,-2.7, 1.0, 2.0,-3.0, 2.0, 1.0),nrow = node[1], ncol = node[2], byrow = TRUE)
    node2_mat = drop(layer1 %*% beta_mat2) - 1
    layer2 = matrix(sigmoid(node2_mat), nrow = n, ncol = node[2])
    
    # beta_mat3 = matrix(c(2, -1, -3, 1.5, -2, -2), nrow = node[2], ncol = node[3])
    # node3_mat = drop(layer2 %*% beta_mat3) + 0.5
    # layer3 = matrix(sigmoid(node3_mat), nrow = n, ncol = node[3])
    
    output_beta1 = c(3.1, -2.9, 0.5)
    output_beta2 = c(-1.7, 4.1, 1.6)
    output_beta3 = c(2.5, -2, 4.1)
    # prob1 = sigmoid(drop(layer3 %*% output_beta1 - 5))
    # prob2 = sigmoid(drop(layer3 %*% output_beta2 - 3))
    # prob3 = 1 - prob1 - prob2
    
    # lr1 = drop(layer2 %*% output_beta1)
    # lr2 = drop(layer2 %*% output_beta2)
    # lr3 = drop(layer2 %*% output_beta3)
    # lr = cbind(lr1, lr2, lr3)
    
    prob1 = sigmoid(drop(layer2 %*% output_beta1))
    prob2 = sigmoid(drop(layer2 %*% output_beta2))
    prob3 = sigmoid(drop(layer2 %*% output_beta3))
    probs = cbind(prob1, prob2, prob3)
    
    # const = (1 + exp(lr1) + exp(lr2))
    # prob1 = exp(lr1) / const
    # prob2 = exp(lr2) / const
    # prob3 = 1 / const
    # probs = cbind(prob1, prob2, prob3)
    # y = apply(probs, 1, function(x) sample(1:3, 1, TRUE, x))
    y = apply(probs, 1, which.max)
    # y = apply(lr, 1, which.max)
    # table(y)
    
    # const = (1 + exp(lr1) + exp(lr2))
    # prob1 = exp(lr1) / const
    # prob2 = exp(lr2) / const
    # prob3 = 1 / const
    # probs = cbind(prob1, prob2, prob3)
    # y = apply(probs, 1, function(x) sample(1:3, 1, TRUE, x))
    # y = apply(probs, 1, which.max)
    # y = apply(lr, 1, which.max)
    # table(y)
    # y = 2 * rbinom(n, 1, prob) - 1
    noise = matrix(rnorm(n * (p - r), 0, 2.0), n, (p - r))
    X = cbind(X_tmp[, -3], noise)
    true_vec = c(rep(1, r), rep(0, p - r))
    out = list()
    out$x = X
    out$y = y
    out$true = true_vec
    out$probs = probs
}
return(out)
}



# binary case, class 2 generate simulation

bsim_gen = function(n, p, seed = NULL, type = c("linear", "linearA", "linearB", "linearC", "linearD"))
{
    call = match.call()
    type = match.arg(type)

    if (!is.null(seed)) {
    set.seed(seed)
}
if (type == "linear") {
    dat = mlbench.2dnormals(n = n, cl = 2, sd = 1)
    X_true = dat$x
    y = dat$classes
    r = ncol(X_true)
    X_noise = matrix(rnorm(n * (p - r), sd = 1), nrow = n, ncol = p - r)
    X = cbind(X_true, X_noise)

    out = list()
    out$x = X
    out$y = y
    out$true = rep(c(1, 0), c(r, p - r)) # 1이면 true값, 0이면 noise
}

if (type == "linearA") {
rho = matrix(0, 8, 8)
diag(rho) = 1

for (i in 1:8){
    for (j in 1:8){
        if (i == j){
            rho[i,j] = 1
        }
        else{
            rho[i,j] = 0.5^(abs(i - j))
        }
}
}

mutemp = rep(0, 8)
X = mvrnorm(n = n, mu = mutemp, Sigma = rho)
beta = c(3, 1.5, 1e-4, 1e-4, 2, 1e-4, 1e-4, 1e-4)

for (i in 1:8){
    X[,i] = X[,i] * beta[i]
}

prob = exp(X) / (1 + exp(X))
y = rbinom(n = n, size = 1 ,prob = prob)

y_temp = factor(y)
classname = levels(y_temp)
n_class = length(classname)

y_int = integer(length(y))
for (j in 1:n_class) {y_int[which(y_temp %in% classname[j])] = j}
if (is(y, "numeric")) {classname = as.numeric(classname)}
y_int = ifelse(y_int == 1, 1, -1)

r = ncol(X)
X_noise = matrix(rnorm(n * (p - r), sd = 1), nrow = n, ncol = p - r)
X = cbind(X, X_noise)

out = list()

out$x = X
out$y = y
out$true = rep(c(1, 0), c(r, p - r)) # 1이면 true값, 0이면 noise

}

if (type == "linearB") {
rho = matrix(0, 10, 10)
diag(rho) = 1

for (i in 1:10){
    for (j in 1:10){
        if (i == j){
            rho[i,j] = 1
        }
        else{
            rho[i,j] = 0.5
        }
}
}

mutemp = rep(0, 10)
X = mvrnorm(n = n, mu = mutemp, Sigma = rho)
beta = c(2, 2, 2, 2, 2, 1e-4, 1e-4, 1e-4, 1e-4, 1e-4)


for (i in 1:10){
    X[,i] = X[,i] * beta[i]
}

prob = exp(X) / (1 + exp(X))
y = rbinom(n = n, size = 1 ,prob = prob)

y_temp = factor(y)
classname = levels(y_temp)
n_class = length(classname)

y_int = integer(length(y))
for (j in 1:n_class) {y_int[which(y_temp %in% classname[j])] = j}
if (is(y, "numeric")) {classname = as.numeric(classname)}
y_int = ifelse(y_int == 1, 1, -1)

if (p > ncol(X))
{
r = ncol(X)
X_noise = matrix(rnorm(n * (p - r), sd = 1), nrow = n, ncol = p - r)
X = cbind(X, X_noise)
}
else {
    r = 0
}

out = list()

out$x = X
out$y = y
out$true = rep(c(1, 0), c(r, p - r)) # 1이면 true값, 0이면 noise

}


if (type == "linearC") {
rho = matrix(0, 40, 40)
diag(rho) = 1

for (i in 1:40){
    for (j in 1:40){
        if (i == j){
            rho[i,j] = 1
        }
        else{
            rho[i,j] = 0.5^(abs(i - j))
        }
}
}

mutemp = rep(0, 40)
X = mvrnorm(n = n, mu = mutemp, Sigma = rho)

beta = as.vector(cbind(rep(1e-4,10),rep(2,10),rep(1e-4,10),rep(2,10)))

for (i in 1:40){
    X[,i] = X[,i] * beta[i]
}

prob = c()
y = c()

for (i in 1:n){
prob[i] = exp(X[i]) / (1 + exp(X[i]))
y[i] = rbinom(n = 1, size = 1 ,prob = prob)
}

y_temp = factor(y)
classname = levels(y_temp)
n_class = length(classname)

y_int = integer(length(y))
for (j in 1:n_class) {y_int[which(y_temp %in% classname[j])] = j}
if (is(y, "numeric")) {classname = as.numeric(classname)}
y_int = ifelse(y_int == 1, 1, -1)

r = ncol(X)
X_noise = matrix(rnorm(n * (p - r), sd = 1), nrow = n, ncol = p - r)
X = cbind(X, X_noise)

out = list()

out$x = X
out$y = y
out$true = rep(c(1, 0), c(r, p - r)) # 1이면 true값, 0이면 noise

}


if (type == "linearD") {
rho = matrix(0, 40, 40)
diag(rho) = 1

for (i in 1:40){
    for (j in 1:40){
        if (i == j){
            rho[i,j] = 1
        }
        else{
            rho[i,j] = 0.5
        }
}
}

mutemp = rep(0, 40)
X = mvrnorm(n = n, mu = mutemp, Sigma = rho)

beta = as.vector(cbind(rep(1e-4,10),rep(2,10),rep(1e-4,10),rep(2,10)))

for (i in 1:40){
    X[,i] = X[,i] * beta[i]
}

prob = c()
y = c()

for (i in 1:n){
prob[i] = exp(X[i]) / (1 + exp(X[i]))
y[i] = rbinom(n = 1, size = 1 ,prob = prob)
}

y_temp = factor(y)
classname = levels(y_temp)
n_class = length(classname)

y_int = integer(length(y))
for (j in 1:n_class) {y_int[which(y_temp %in% classname[j])] = j}
if (is(y, "numeric")) {classname = as.numeric(classname)}
y_int = ifelse(y_int == 1, 1, -1)

r = ncol(X)
X_noise = matrix(rnorm(n * (p - r), sd = 1), nrow = n, ncol = p - r)
X = cbind(X, X_noise)

out = list()

out$x = X
out$y = y
out$true = rep(c(1, 0), c(r, p - r)) # 1이면 true값, 0이면 noise

}

return(out)
}


