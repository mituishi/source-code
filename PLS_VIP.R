library(plsVarSel)

#----------��������VIP-------------------------
comp <- which.min(compounds.plsr$validation$PRESS)
vip <- VIP(compounds.plsr,comp)
vip
plot(vip,compounds.plsr$coefficients[, , ncomp.onesigma])
vip.selected <- bve_pls(preprocessed.y, preprocessed.x) 
vip.selected
