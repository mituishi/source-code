  library(readr) # データ読み込み
  library(dplyr) # データ操作一般
  library(assertr) # データのチェック
  library(rsample)

#Packages installation
library(genalg)
library(pls)
library(e1071)
library(kernlab)
library(iml)
library(devtools)

pkgs <- c('foreach', 'doParallel')
lapply(pkgs, require, character.only = T)
#if you want to change the number of threads for the calculation, please change the value "detectCores()"
registerDoParallel(makeCluster(detectCores()))


#-----------pick up the file path--------------
path <- file.choose()
path

#-----------read csv file as compounds--------------
compounds <- read.csv(path)
View(compounds)

#-----------remove some columns if needed--------------
trimed.compounds <- compounds[,]

#-----------select rows without empty cells---------
is.completes <- complete.cases(trimed.compounds)
is.completes

complete.compounds <- trimed.compounds[is.completes,]
View(complete.compounds)

#-----------select x from the dataset-----------------
x <- complete.compounds[,c(3:35)]
View(x)
x.2 <- complete.compounds[,c(6:11,13,17:25)]
View(x.2)

#-----------calculate standard distribution of x------
x.sds <- apply(x, 2, sd)
x.sds[1]

x.mean <- apply(x, 2, mean)
x.mean[2]
x.mean

#-----------remove columns of 0 distribution from x----
sd.is.not.0 <- x.sds != 0
x <- x[, sd.is.not.0]
View(x)

#-----------select y from the dataset------------------
y <- complete.compounds[,c(2)]
y

#-----------standarization of y------------------------
preprocessed.y <- (y - mean(y)) / sd(y)
mean(preprocessed.y)
sd(preprocessed.y)

#-----------standarization of x------------------------
apply(x, 2, mean)
apply(x, 2, sd)
preprocessed.x <- apply(x, 2, function(x) {(x - mean(x)) / sd(x)})
View(preprocessed.x)

#-----------x converted into data frame type for machine learning-----------
#class(preprocessed.x)
preprocessed.x <- data.frame(preprocessed.x)
#class(preprocessed.x)

#apply(preprocessed.x, 2, mean)
#apply(preprocessed.x, 2, sd)



#-----------compare the number of columns and rows--------------
ncol(preprocessed.x)
nrow(preprocessed.x)

#-----------pick up columns if needed---------------------------
multi.regression.x <- preprocessed.x[ , ]
View(multi.regression.x)

#-----------definition of multi.regression.compounds (used for MLR)--------
multi.regression.compounds <- cbind(preprocessed.y, multi.regression.x)
View(multi.regression.compounds)

#--------------------divide into test and training data----------------------
train_size = 0.8

n = nrow(multi.regression.compounds)
#------------collect the data with n*train_size from the dataset------------
perm = sample(n, size = round(n * train_size))

#-------------------training data----------------------------------------
multi.regression.compounds.train <- multi.regression.compounds[c(1:round(n*train_size)), ]
preprocessed.y.train <- multi.regression.compounds.train[,c(1)]
multi.regression.x.train <- multi.regression.compounds.train[,-c(1)]
#-----------------------test data----------------------------------------
multi.regression.compounds.test <-multi.regression.compounds[-c(1:round(n*train_size)), ]
preprocessed.y.test <- multi.regression.compounds.test[,c(1)]
multi.regression.x.test <- multi.regression.compounds.test[,-c(1)]

#-----------transform into data frame--------------------------
multi.regression.compounds.train <- as.data.frame(multi.regression.compounds.train)

#---------------------------stepwise variables selection--------------------------------------------
#Generating initial dataset(train and test)
multi.regression.compounds.train.s <- cbind(preprocessed.y.train, multi.regression.x.train[,])
multi.regression.x.train.s <- multi.regression.x.train[,]
multi.regression.compounds.test.s <- cbind(preprocessed.y.test,multi.regression.x.test)
multi.regression.x.test.s <- multi.regression.x.test[,]

n.validation.int <- 5
n.validation <- n.validation.int + 1
ratio.train <- 1 

split.num <- n.validation + ratio.train

#Definition of best performance data for each cases
best.performance.cv <- matrix(data = 0, nrow = ncol(multi.regression.x.train), ncol = 2)
best.performance.cv[,c(2)] <- seq(1:ncol(multi.regression.x.train))
variables.step <- colnames(preprocessed.x)
importance.cv <- matrix(data = 0, nrow = ncol(multi.regression.x.train), ncol = ncol(multi.regression.x.train))
rownames(importance.cv) <- colnames(multi.regression.x.train)

#Stepwise variables elimination
for(j in 1:(ncol(preprocessed.x) - 10)){
  
  #SVM hyperparameter tuning  
  #determining initial gamma by maximizing kernel matrix variance
  xtrain = multi.regression.x.train.s
  datasum = multi.regression.compounds.train.s
  
  df2 <- datasum
  ### SPLIT DATA INTO K FOLDS ###
  set.seed(2016)
  
  df2fold <- rolling_origin(multi.regression.compounds, initial = round(nrow(multi.regression.compounds) / split.num * ratio.train), 
                 assess = round(nrow(multi.regression.compounds) / split.num), 
                 skip = round(nrow(multi.regression.compounds) / split.num), 
                 cumulative = FALSE)

  ### PARAMETER LIST ###
  cost <- 3
  epsilon <- c(-10,-9,-8,-7,-6,-5,-4,-3,-2,-1, 0)

  gam <- foreach(k = -20:10, .combine = rbind)%dopar%{
    rbf <- rbfdot(sigma = 2^k)
    rbf
    
    asmat <- as.matrix(Xtrain)
    asmat
    
    kern <- kernelMatrix(rbf, asmat)
    sd(kern)
    data.frame((k +21), sd(kern))
  }
  
  hakata <- which.max(gam$sd.kern.)

  gamma <- hakata - 21
  parms <- expand.grid(epsilon = epsilon, cost = cost, gamma = gamma)
  ### LOOP THROUGH PARAMETER VALUES ###
  result <- foreach(i = 1:nrow(parms), .combine = rbind, .packages = c("foreach", "doParallel", "readr", "dplyr", "assertr", "rsample")) %dopar% {
    c <- parms[i, ]$cost
    g <- parms[i, ]$gamma
    e <- parms[i, ]$epsilon
    ### K-FOLD VALIDATION ###
    out <- foreach(j = 1:(n.validation -1), .combine = rbind,.packages = c("foreach", "doParallel", "readr", "dplyr", "assertr", "rsample"), .inorder = FALSE) %dopar% {
      deve <- df2[df2fold$splits[[j]]$in_id, ]
      test <- na.omit(df2[df2fold$splits[[j]]$out_id, ])
      mdl <- e1071::svm(preprocessed.y.train~., data = deve, cost = c, gamma = 2^g, epsilon = 2^e)
      pred <- predict(mdl, test)
      data.frame(test[, c(1)], pred)
      
    }
    ### CALCULATE SVM PERFORMANCE ###
    roc <- sum((out[, c(1)] - out[, c(2)])^2) / nrow(out)
    data.frame(parms[i, ], roc)
  }
  
  
  epsilon <- min(result[result[, c(4)] <= (min(result[,c(4)])), c(1)])
  cost <- c(-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10)
  parms <- expand.grid(epsilon = epsilon, cost = cost, gamma = gamma)
  ### LOOP THROUGH PARAMETER VALUES ###
  result <- foreach(i = 1:nrow(parms), .combine = rbind, .packages = c("foreach", "doParallel", "readr", "dplyr", "assertr", "rsample")) %dopar% {
    c <- parms[i, ]$cost
    g <- parms[i, ]$gamma
    e <- parms[i, ]$epsilon
    ### K-FOLD VALIDATION ###
    out <- foreach(j = 1:(n.validation -1), .combine = rbind,.packages = c("foreach", "doParallel", "readr", "dplyr", "assertr", "rsample"), .inorder = FALSE) %dopar% {
      deve <- df2[df2fold$splits[[j]]$in_id, ]
      test <- na.omit(df2[df2fold$splits[[j]]$out_id, ])
      mdl <- e1071::svm(preprocessed.y.train~., data = deve, cost = 2^c, gamma = 2^g, epsilon = 2^e)
      pred <- predict(mdl, test)
      data.frame(test[, c(1)], pred)
      
    }
    ### CALCULATE SVM PERFORMANCE ###
    roc <- sum((out[, c(1)] - out[, c(2)])^2) / nrow(out)
    data.frame(parms[i, ], roc)
  }

  cost <- min(result[(result[, c(4)] <= (min(result[,c(4)]))), c(2)])
  gamma <- c(-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10)
  parms <- expand.grid(epsilon = epsilon, cost = cost, gamma = gamma)
  ### LOOP THROUGH PARAMETER VALUES ###
  result <- foreach(i = 1:nrow(parms), .combine = rbind, .packages = c("foreach", "doParallel", "readr", "dplyr", "assertr", "rsample")) %dopar% {
    c <- parms[i, ]$cost
    g <- parms[i, ]$gamma
    e <- parms[i, ]$epsilon
    ### K-FOLD VALIDATION ###
    out <- foreach(j = 1:(n.validation -1), .combine = rbind,.packages = c("foreach", "doParallel", "readr", "dplyr", "assertr", "rsample"), .inorder = FALSE) %dopar% {
      deve <- df2[df2fold$splits[[j]]$in_id, ]
      test <- na.omit(df2[df2fold$splits[[j]]$out_id, ])
      mdl <- e1071::svm(preprocessed.y.train~., data = deve, cost = 2^c, gamma = 2^g, epsilon = 2^e)
      pred <- predict(mdl, test)
      data.frame(test[, c(1)], pred)
      
    }
    ### CALCULATE SVM PERFORMANCE ###
    roc <- sum((out[, c(1)] - out[, c(2)])^2) / nrow(out)
    data.frame(parms[i, ], roc)
  }

  gamma <- min(result[(result[, c(4)] <= (min(result[,c(4)]))), c(3)])
  bestperformance <- min(result[, c(4)])
  returnVal = bestperformance
  
  compounds.svr.s <- svm(multi.regression.x.train.s, preprocessed.y.train, gammma = 2^gamma, cost = 2^cost, epsilon = 2^epsilon)
  
  best.performance.cv[c(j), c(1)] <- returnVal
  mod = Predictor$new(compounds.svr.s, data = multi.regression.x.train.s, y = preprocessed.y.train)
  imp = FeatureImp$new(mod, loss = "mse", compare = "ratio", n.repetitions = 5, parallel = TRUE)
  eliminate <- imp$results[-c(which.min(imp$results[,c(3)])), c(1)]
  eliminate
  importance.cv[imp$results[,c(1)],c(j)] <- (imp$results[,c(3)])
  
  multi.regression.compounds.train.s <- cbind(preprocessed.y.train, multi.regression.x.train.s[,c(eliminate)])
  multi.regression.x.train.s <- multi.regression.x.train.s[,c(eliminate)]
  multi.regression.compounds.test.s <- cbind(preprocessed.y.test, multi.regression.x.test.s[,c(eliminate)])
  multi.regression.x.test.s <- multi.regression.x.test.s[,c(eliminate)]
  
  #output selected variables for each steps
  variables.step <- cbind(variables.step, colnames(multi.regression.x.train.s))
  View(variables.step)
  View(best.performance.cv)
  View(importance.cv)
}

plot(best.performance.cv[, c(1)], ylim = c(0, 0.3), xlim = c(0,250), ylab = "MSECV", xlab = "Generation", col = "blue", pch = 2)
par(new=T)
plot(nir.results$best, ylim = c(0,0.3), xlim = c(0,250), ylab = "", xlab = "", lty = 2, type = "b")
par(new=T)
plot(nir.results$mean, ylim = c(0, 0.3), ylab = "MSECV", col = "blue", type = "b", pch = 2)


write.csv(importance.cv, "C:/Users/uni21/OneDrive/デスクトップ/importance.csv")

#output the selected variables
colnames(multi.regression.x.train.s)

#generating SVM model with selected variables
gam <- matrix(data = 0, nrow = 31, ncol = 1)
for(k in -20:10){
  rbf <- rbfdot(sigma = 2^k)
  rbf
  
  asmat <- as.matrix(multi.regression.x.train.s.t)
  asmat
  
  kern <- kernelMatrix(rbf, asmat)
  sd(kern)
  gam[c(k + 21),] <- sd(kern)
}

hakata <- which.max(gam)

obj.se.t.t <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s, gamma = 2^(hakata - 21), cost = 3, epsilon = 2^(-10:0))
obj.sc.t.t <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s, gamma = 2^(hakata - 21), cost = 2^(-5:10), epsilon = obj.se.t.t$best.parameters[,c(3)])
obj.s.t.t <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s, gamma = 2^(-20:10), cost = obj.sc.t.t$best.parameters[,c(2)], epsilon = obj.se.t.t$best.parameters[,c(3)])
obj.s.t.t$best.model
compounds.svr.s.t.t <- svm(multi.regression.x.train.s,preprocessed.y.train,gammma = obj.s.t.t$best.parameters[,c(1)], cost = obj.s.t.t$best.parameters[,c(2)], epsilon = obj.s.t.t$best.parameters[,c(3)])
summary(compounds.svr.s.t.t)
obj.s.t.t$best.performance

#testing the model accuracy
svm.predicted.y.test.s.t.t <- predict(compounds.svr.s.t.t, newdata = multi.regression.x.test.s)
plot(preprocessed.y.test, svm.predicted.y.test.s.t.t,
     xlab="Observed value",
     ylab="Predicted value", main = "SVM test")
abline(a=0, b=1)

svm.r2.test.s.t.t <- cor(preprocessed.y.test,svm.predicted.y.test.s.t.t)**2
svm.r2.test.s.t.t

