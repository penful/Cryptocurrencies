##############
#### Example code of the paper
#### Exploring the dependencies among main cryptocurrency log‐returns: A hidden Markov model####
###  Pennoni, F., Bartolucci, F., Forte, G., Ametrano, F. (2021)
##############

# Example data with the log-returns of three crypto
load("data.RData")
require(LMest)
require(mvtnorm)
require(Formula)
require(mix)
source("lmestFormula.R")
source("lmbasic.cont.R")
source("lmestCont.R")
source("functions.R")
source("complk_cont_miss.R")



#### Model Selection and Estimation ####
eqSi = FALSE # option FALSE for state specific variance-covariance matrix
modv = vector("list",2)
for(k in 1:2){
  print(k)
  modv[[k]] <- lmestCont(responsesFormula = zz1 + zz2 + zz3  ~ NULL,
                         index = c("id","t"),
                         data = data, 
                         k = k,
                         modBasic = 1,
                         tol=10^-10, eqSi=eqSi)
  if(k>1){
    # this is an example: increase l up to 10
    l <- 2
    for(k1 in 1:(l*(k-1))){
      print(c(k,k1))
      tmp <- lmestCont(responsesFormula = zz1 + zz2 + zz3  ~ NULL,
                       index = c("id","t"), 
                       data = data, k = k, 
                       modBasic = 1,
                       tol=10^-10, start = 1,eqSi=eqSi)
      if(tmp$lk>modv[[k]]$lk){
        modv[[k]] = tmp
        print("change")
      }
    }
  }
}


