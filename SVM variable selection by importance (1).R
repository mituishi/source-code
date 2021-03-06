#-----------pick up the file path--------------
path <- file.choose()
path

#-----------read csv file as compounds--------------
compounds <- read.csv(path)

#-----------remove some columns if needed--------------
trimed.compounds <- compounds[,]

#-----------select rows without empty cells---------
is.completes <- complete.cases(trimed.compounds)
is.completes

complete.compounds <- trimed.compounds[is.completes,]

#-----------select x from the dataset-----------------
x.0 <- complete.compounds[,-c(1)]
x.2 <- apply(x.0,2,function(x.0) {x.0**2}) #add nonlinear columns
x.3 <- apply(x.0,2,function(x.0) {x.0**3}) #add nonlinear columns

x <- cbind.data.frame(x.0,x.2,x.3)


#-----------remove columns of 0 distribution from x----
x.sds <- apply(x, 2, sd)
sd.is.not.0 <- x.sds != 0
x <- x[, sd.is.not.0]

#-----------select y from the dataset------------------
y <- complete.compounds[,c(1)]

#-----------standarization of y------------------------
preprocessed.y <- (y - mean(y)) / sd(y)
mean(preprocessed.y)
sd(preprocessed.y)

#-----------standarization of x------------------------
apply(x, 2, mean)
apply(x, 2, sd)
preprocessed.x <- apply(x, 2, function(x) {(x - mean(x)) / sd(x)})
preprocessed.x <- data.frame(preprocessed.x)

#-----------compare the number of columns and rows--------------
ncol(preprocessed.x)
nrow(preprocessed.x)

#-----------pick up columns if needed---------------------------
multi.regression.x <- preprocessed.x[ , ]

#-----------definition of multi.regression.compounds (used for MLR)--------
multi.regression.compounds <- cbind(preprocessed.y, multi.regression.x)

#--------------------divide into test and training data----------------------
train_size = 0.1

n = nrow(multi.regression.compounds)
#------------collect the data with n*train_size from the dataset------------
perm = sample(n, size = round(n * train_size))

#-------------------training data----------------------------------------
multi.regression.compounds.train <- multi.regression.compounds[perm, ]
preprocessed.y.train <- multi.regression.compounds.train[,c(1)]
multi.regression.x.train <- multi.regression.compounds.train[,-c(1)]
#-----------------------test data----------------------------------------
multi.regression.compounds.test <-multi.regression.compounds[-perm, ]
preprocessed.y.test <- multi.regression.compounds.test[,c(1)]
multi.regression.x.test <- multi.regression.compounds.test[,-c(1)]

#-----------transform into data frame--------------------------
multi.regression.compounds.train <- as.data.frame(multi.regression.compounds.train)

#-------------Installing SVM library---------------------------------
library(e1071)
library(kernlab)
library(iml)
library(devtools)

#--------------------------variables elimination by importance threshold in SVM-------------------------------
multi.regression.compounds.train.s.t <- cbind(preprocessed.y.train, multi.regression.x.train[,])
multi.regression.x.train.s.t <- multi.regression.x.train[,]
multi.regression.compounds.test.s.t <- cbind(preprocessed.y.test,multi.regression.x.test)
multi.regression.x.test.s.t <- multi.regression.x.test[,]

#model optimization with all variables
#determining initial gamma by maximizing kernel matrix variance
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

obj.se.t <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s.t, gamma = 2^(hakata - 21), cost = 3, epsilon = 2^(-10:0))
obj.sc.t <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s.t, gamma = 2^(hakata - 21), cost = 2^(-5:10), epsilon = obj.se.t$best.parameters[,c(3)])
obj.s.t <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s.t, gamma = 2^(-20:10), cost = obj.sc.t$best.parameters[,c(2)], epsilon = obj.se.t$best.parameters[,c(3)])
compounds.svr.s.t <- svm(multi.regression.x.train.s.t,preprocessed.y.train,gammma = obj.s.t$best.parameters[,c(1)], cost = obj.s.t$best.parameters[,c(2)], epsilon = obj.s.t$best.parameters[,c(3)])

#------------------------------feature importance calculation----------------------------------------------
mod = Predictor$new(compounds.svr.s.t, data = multi.regression.x.train.s.t, y = preprocessed.y.train)
imp = FeatureImp$new(mod, loss = "mse", compare = "ratio", n.repetitions = 50)
imp$results
plot(imp)

#--------------------variable selection threshold by onesigma method------------------
threshold <- min(imp$results[, c(3)]) + mean(imp$results[, c(4)] - imp$results[, c(2)]) / 3.92
acq <- cbind(imp$results[, c(1)], imp$results[, c(3)])
kamakura <- acq[acq[, c(2)] > threshold, c(1)]
kamakura

#------------elimination of variables with low importance------------------------------
  multi.regression.compounds.train.s.t <- cbind(preprocessed.y.train, multi.regression.x.train.s.t[, c(kamakura)])
  multi.regression.x.train.s.t <- multi.regression.x.train.s.t[, c(kamakura)]
  multi.regression.compounds.test.s.t <- cbind(preprocessed.y.test, multi.regression.x.test.s.t[, c(kamakura)])
  multi.regression.x.test.s.t <- multi.regression.x.test.s.t[, c(kamakura)]

#---------------------generating SVM model with selected variables----------------------
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

obj.se.t.e <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s.t, gamma = 2^(hakata - 21), cost = 3, epsilon = 2^(-10:0))
obj.sc.t.e <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s.t, gamma = 2^(hakata - 21), cost = 2^(-5:10), epsilon = obj.se.t.e$best.parameters[,c(3)])
obj.s.t.e <- tune.svm(preprocessed.y.train~., data = multi.regression.compounds.train.s.t, gamma = 2^(-20:10), cost = obj.sc.t.e$best.parameters[,c(2)], epsilon = obj.se.t.e$best.parameters[,c(3)])
obj.s.t.e$best.model
compounds.svr.s.t.e <- svm(multi.regression.x.train.s.t,preprocessed.y.train,gammma = obj.s.t.e$best.parameters[,c(1)], cost = obj.s.t.e$best.parameters[,c(2)], epsilon = obj.s.t.e$best.parameters[,c(3)])
summary(compounds.svr.s.t.e)
obj.s.t.e$best.performance

#--------------------------testing the model accuracy------------------------------------------
svm.predicted.y.test.s.t.e <- predict(compounds.svr.s.t.e, newdata = multi.regression.x.test.s.t)
plot(preprocessed.y.test, svm.predicted.y.test.s.t.e,
     xlab="Observed value",
     ylab="Predicted value", main = "SVM test")
abline(a=0, b=1)

svm.r2.test.s.t.e <- cor(preprocessed.y.test,svm.predicted.y.test.s.t.e)**2
svm.r2.test.s.t.e

