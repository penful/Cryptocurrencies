lmbasic.cont <- function(Y,k,start=0,modBasic=0,tol=10^-8,maxit=100,out_se=FALSE,eqSi = TRUE,
                         piv=NULL,Pi=NULL,Mu=NULL,Si=NULL, miss = FALSE, fort = TRUE){

  # *** to change ***
  fort = FALSE

      # Preliminaries
  check_der = FALSE  # to check derivatives
  sY = dim(Y)
  n = sY[1]
  TT = sY[2]
  mod <- modBasic
  if(length(sY)==2){
    r = 1
    if(is.matrix(Y)) Y = array(Y,c(dim(Y),1))
  }else r = sY[3]

  Yv = matrix(Y,n*TT,r)
  ## Check and inpute for missing data

  R = (!is.na(Y))
  if(fort) RR = array(as.integer(1*R),c(n,TT,r))

  if(miss){
    Yv = cbind(1,Yv)
    pYv = prelim.mix(Yv,1)
    thhat = em.mix(pYv)
    rngseed(1)
    Yv = as.matrix(imp.mix(pYv, da.mix(pYv,thhat,steps=100), Yv)[,-1])
    Y = array(Yv,c(n,TT,r))
    cat("Missing data in the dataset. imp.mix function (mix package) used for imputation.\n")
  }
  miss = FALSE 
  R = (!is.na(Y))  
  if(fort) RR = array(as.integer(1*R),c(n,TT,r))  

  th = NULL; sc = NULL; J = NULL
  if(out_se){
    B = cbind(-rep(1,k-1),diag(k-1))
    Bm = rbind(rep(0,k-1),diag(k-1))
    C = array(0,c(k-1,k,k))
    Cm = array(0,c(k,k-1,k))
    for(u in 1:k){
      C[,,u] = rbind(cbind(diag(u-1),-rep(1,u-1),matrix(0,u-1,k-u)),
                     cbind(matrix(0,k-u,u-1),-rep(1,k-u),diag(k-u)))
      Cm[,,u] = rbind(cbind(diag(u-1),matrix(0,u-1,k-u)),
                      rep(0,k-1),
                      cbind(matrix(0,k-u,u-1),diag(k-u)))
    }
  }

  # just 1 latent class
  if(k == 1){
    piv = 1; Pi = 1
    Mu = colMeans(Yv,na.rm=TRUE)
    Si = cov(Yv,use = "complete.obs")
    lk = sum(dmvnorm(Yv,Mu,Si,log=TRUE))
    np = k*r
    np = r*(r+1)/2
    aic = -2*lk+np*2
    if(n==1) bic = -2*lk+np*log(TT) else bic = -2*lk+np*log(n)   #FB
    out = list(lk=lk,piv=piv,Pi=Pi,Mu=Mu,Si=Si,np=np, k = k, aic=aic,bic=bic,lkv=NULL,V=NULL,n = n, TT = TT, modBasic = mod )
    class(out)="LMbasiccont"
    return(out)
  }

    # Starting values
  if(start == 0){
    out = kmeans(Yv,k,nstart = 1000)
    Mu = t(out$centers)
    piv = rep(0,k); piv[out$cluster[1]] = 1
    Pi = matrix(0,k,k)
    for(h1 in 1:k) for(h2 in 1:k) Pi[h1,h2] = sum(out$cluster[-1]==h1 & out$cluster[-TT]==h2)
    Pi = Pi/rowSums(Pi)
    Pi = array(Pi,c(k,k,TT))
    if(eqSi){
      Si = 0
      for(h in 1:k) Si = Si+cov(Yv[out$cluster==h,])+Mu[,h]%o%Mu[,h]
      Si = Si-colMeans(Yv)%o%colMeans(Yv)
    }else{
      Si = array(0,c(r,r,k))
      for(h in 1:k) Si[,,h] = cov(Yv[out$cluster==h,])
    }
    Pi[,,1] = 0
  }
  if(start==1){
    Mu = matrix(0,r,k)
    mu = colMeans(Yv,na.rm=TRUE)
    Si = cov(Yv,use = "complete.obs")
    for(u in 1:k) Mu[,u] = rmvnorm(1,mu,Si)
    if(!eqSi) Si = array(Si,c(r,r,k))
    Pi = array(runif(k^2*TT),c(k,k,TT))
    for(t in 2:TT) Pi[,,t] = (1/rowSums(Pi[,,t]))*Pi[,,t]  #FB
    Pi[,,1] = 0
    piv = runif(k); piv = piv/sum(piv)
  }
  if(start==2){
    if(is.null(piv)) stop("initial value of the initial probabilities (piv) must be given in input")
    if(is.null(Pi)) stop("initial value of the transition probabilities (Pi) must be given in input")
    if(is.null(Mu)) stop("initial value of the conditional means of the response variables (Mu) must be given in input")
    if(is.null(Si)) stop("initial value of the var-cov matrix common to all states (Si) must be given in input")
    piv = piv
    Pi = Pi
    Mu = Mu
    Si = Si
  }

  # Compute log-likelihood
  if(eqSi) Si1 = array(Si,c(r,r,k)) else Si1 = Si
  out = complk_cont_miss(Y,R,piv,Pi,Mu,Si1,k, fort = fort, eqSi=FALSE)
  lk = out$lk; Phi = out$Phi; L = out$L; pv = out$pv
  cat("------------|-------------|-------------|-------------|-------------|-------------|-------------|\n");
  cat("     mod    |      k      |    start    |     step    |     lk      |    lk-lko   | discrepancy |\n");
  cat("------------|-------------|-------------|-------------|-------------|-------------|-------------|\n");
  cat(sprintf("%11g",c(mod,k,start,0,lk)),"\n",sep = " | ")
  it = 0; lko = lk-10^10; lkv = NULL
  par = c(piv,as.vector(Pi),as.vector(Mu),as.vector(Si))
  if(any(is.na(par))) par = par[-which(is.na(par))]
  paro = par
  # Iterate until convergence
  while((lk-lko)/abs(lk)>tol & it<maxit){
    # t0 = proc.time()
    Mu0 = Mu; Si0 = Si; piv0 = piv; Pi0 = Pi
    it = it+1;
    # ---- E-step ----
    # Compute V and U
    V = array(0,c(n,k,TT)); U = array(0,c(k,k,TT))
    M = matrix(1,n,k)
    if(n==1) V[,,TT] = L[,,TT]/sum(L[1,,TT])
    else V[,,TT] = L[,,TT]/rowSums(L[,,TT])
    if(FALSE){
      U[,,TT] = .Fortran("prodnorm",L[,,TT-1],Phi[,,TT],Pi[,,TT],n,k,D=matrix(0,k,k))$D
    }else{
      for(i in 1:n){
        Tmp = (L[i,,TT-1]%o%Phi[i,,TT])*Pi[,,TT]
        U[,,TT] = U[,,TT]+Tmp/sum(Tmp)
      }
    }
    if(TT>2){
      for(t in seq(TT-1,2,-1)){
        M = (Phi[,,t+1]*M)%*%t(Pi[,,t+1])
        M = M/rowSums(M)
        V[,,t] = L[,,t]*M
        if(n==1) V[,,t] = V[,,t]/sum(V[1,,t])
        else V[,,t] = V[,,t]/rowSums(V[,,t])
        if(FALSE){
          U[,,t] = .Fortran("prodnorm",L[,,t-1],Phi[,,t]*M,Pi[,,t],n,k,D=matrix(0,k,k))$D
        }else{
          for(i in 1:n){
            Tmp = (L[i,,t-1]%o%(Phi[i,,t]*M[i,]))*Pi[,,t]
            U[,,t] = U[,,t]+Tmp/sum(Tmp)
          }
        }
      }
    }
    # print(c(1,proc.time()-t0))
    M = (Phi[,,2]*M)%*%t(Pi[,,2])
    M = M/rowSums(M)
    V[,,1] = L[,,1]*M
    if(n==1) V[,,1] = V[,,1]/sum(V[1,,1])
    else V[,,1] = V[,,1]/rowSums(V[,,1])
    # If required store parameters
    # ---- M-step ----
    # Update Mu
    Vv = matrix(aperm(V,c(1,3,2)),n*TT,k)
    if(miss){
      Y1 = array(Y,c(n,TT,r,k))
      Var = array(0,c(n,TT,r,r))
      if(fort){
        out = .Fortran("updatevar",Y,RR,n,TT,r,k,Mu,Si,Y1=Y1,Var=Var)
        Y1 = out$Y1; Var = out$Var
      }else{
        for(i in 1:n) for(t in 1:TT){
          nr = sum(R[i,t,])
          if(nr==0){
            Y1[i,t,,] = Mu
            Var[i,t,,] = Si
          }else if(nr<r){
            indo = R[i,t,]; indm = !R[i,t,]
            Tmp = Si[indm,indo]%*%solve(Si[indo,indo])
            Var[i,t,indm,indm] = Si[indm, indm]-Tmp%*%Si[indo,indm]
            for(u in 1:k) Y1[i,t,indm,u] = Mu[indm,u]+Tmp%*%(Y[i,t,indo]-Mu[indo,u])
          }
        }
      }
      Sitmp = matrix(0,r,r)
      for(u in 1:k){
        Yv1 = matrix(Y1[,,,u],n*TT)
        Var1 = array(Var,c(n*TT,r,r))
        Mu[,u] = (t(Yv1)%*%Vv[,u])/sum(Vv[,u])
        Tmp = Yv1-rep(1,n*TT)%*%t(Mu[,u])
        Sitmp = Sitmp+t(Tmp)%*%(Vv[,u]*Tmp)+apply(Vv[,u]*Var1,c(2,3),sum)
      }
      Si = Sitmp/(n*TT)
    }else{
      for(u in 1:k) Mu[,u] = (t(Yv)%*%Vv[,u])/sum(Vv[,u])
      if(eqSi){
        Si = matrix(0,r,r)
        for(u in 1:k){
          Tmp = as.matrix(Yv-rep(1,n*TT)%*%t(Mu[,u]))
          Si = Si+ t(Tmp)%*%(Vv[,u]*Tmp)
        }
        Si = Si/(n*TT)
      }else{
        Si = array(0,c(r,r,k))
        for(u in 1:k){
          Tmp = as.matrix(Yv-rep(1,n*TT)%*%t(Mu[,u]))
          Si[,,u] = t(Tmp)%*%(Vv[,u]*Tmp)
          Si[,,u] = Si[,,u]/sum(Vv[,u])
        }
      }
    }
    # Update piv and Pi
    if(n==1) piv = V[,,1]/n else piv = colSums(V[,,1])/n
    U = pmax(U,10^-300)
    if(mod==0) for(t in 2:TT) Pi[,,t] = diag(1/rowSums(U[,,t]))%*%U[,,t]
    if(mod==1){
      Ut = apply(U[,,2:TT],c(1,2),sum)
      Pi[,,2:TT] = array(diag(1/rowSums(Ut))%*%Ut,c(k,k,TT-1))
    }
    if(mod>1){
      Ut1 = U[,,2:mod]
      if(length(dim(Ut1))>2) Ut1 = apply(Ut1,c(1,2),sum)
      Ut2 = U[,,(mod+1):TT]
      if(length(dim(Ut2))>2) Ut2 = apply(Ut2,c(1,2),sum)
      Pi[,,2:mod] = array(diag(1/rowSums(Ut1,2))%*%Ut1,c(k,k,mod-1))
      Pi[,,(mod+1):TT] = array(diag(1/rowSums(Ut2,2))%*%Ut2,c(k,k,TT-mod))
    }
    # Compute log-likelihood
    paro = par; par = c(piv,as.vector(Pi),as.vector(Mu),as.vector(Si))
    if(any(is.na(par))) par = par[-which(is.na(par))]
    lko = lk
    if(eqSi) Si1 = array(Si,c(r,r,k)) else Si1 = Si
    out = complk_cont_miss(Y,R,piv,Pi,Mu,Si1,k, fort = fort, eqSi=FALSE)
    lk = out$lk; Phi = out$Phi; L = out$L; pv = out$pv
    if(it/10 == round(it/10)) cat(sprintf("%11g",c(mod,k,start,it,lk,lk-lko,max(abs(par-paro)))),"\n",sep=" | ")
    lkv = c(lkv,lk)
  }
  V2 = aperm(V,c(1,3,2))
  V2 = aperm(array(V2,c(n,TT,k,r)),c(1,2,4,3))
  if(miss) Yimp = apply(Y1*V2,c(1,2,3),sum) else Yimp = Y # FB
  # Compute information matrix if required
  if(out_se){
    th = NULL
    th = c(th,as.vector(Mu))
    th = c(th,Si[upper.tri(Si,TRUE)])
    th = c(th,B%*%log(piv))
    if(mod==0) for(t in 2:TT) for(u in 1:k) th = c(th,C[,,u]%*%log(Pi[u,,t]))
    if(mod==1) for(u in 1:k) th = c(th,C[,,u]%*%log(Pi[u,,2]))
    th0 = th-10^-5/2
    out = lk_obs_cont(th0,Bm,Cm,k,Y,TT,r,mod)
    lk0 = out$lk; sc0 = out$sc
    lth = length(th)
    scn = rep(0,lth)
    J = matrix(0,lth,lth)
    for(j in 1:lth){
      thj = th0; thj[j] = thj[j]+10^-5
      out = lk_obs_cont(thj,Bm,Cm,k,Y,TT,r,mod)
      scn[j] = (out$lk-lk0)/10^-5
      J[,j] = (out$sc-sc0)/10^-5
    }
    J = -(J+t(J))/2
    Va = ginv(J)
    nMu = r*k
    nSi = r*(r+1)/2
    Va2 = Va[1:(nMu+nSi),1:(nMu+nSi)]
    se2 = sqrt(diag(Va2))
    Va = Va[-(1:(nMu+nSi)),-(1:(nMu+nSi))]
    Om = diag(piv)-tcrossprod(piv,piv)
    M = Om%*%Bm
    if(mod==0){
      for(t in 2:TT) for(u in 1:k){
        Om = diag(Pi[u,,t])-Pi[u,,t]%o%Pi[u,,t]
        M = blkdiag(M,Om%*%Cm[,,u])
      }
    }
    if(mod==1){
      for(u in 1:k){
        Om = diag(Pi[u,,2])-Pi[u,,2]%o%Pi[u,,2]
        M = blkdiag(M,Om%*%Cm[,,u])
      }
    }
    if(mod>1){
      for(u in 1:k){
        Om = diag(Pi[u,,2])-Pi[u,,2]%o%Pi[u,,2]
        M = blkdiag(M,Om%*%Cm[,,u])
      }
      for(u in 1:k){
        Om = diag(Pi[u,,mod+1])-Pi[u,,mod+1]%o%Pi[u,,mod+1]
        M = blkdiag(M,Om%*%Cm[,,u])
      }
    }
    M = as.matrix(M)
    Va = M%*%Va%*%t(M)
    dVa = diag(Va)
    if(any(dVa<0)) warning("Negative elements in the estimated variance-covariance matrix for the parameters estimates")
    se = sqrt(abs(dVa))
    # Divide parameters
    se = c(se2,se)
    seMu = se[1:nMu]
    seSi = se[nMu+(1:nSi)]
    sepiv = se[nMu+nSi+(1:k)]

    if(mod==0) sePi = se[nMu+nSi+k+(1:(k*k*(TT-1)))]
    if(mod==1) sePi = se[nMu+nSi+k+(1:(k*k))]
    if(mod>1) sePi = se[nMu+nSi+k+(1:(k*k*2))]
  }
  # Compute number of parameters
  np = (k-1)+k*r
  if(eqSi) np = np+r*(r+1)/2 else np = np+k*r*(r+1)/2
  if(mod==0) np = np+(TT-1)*k*(k-1)
  if(mod==1) np = np+k*(k-1)
  if(mod>1) np = np+2*k*(k-1)
  aic = -2*lk+np*2
  if(n==1) bic = -2*lk+np*log(TT) else bic = -2*lk+np*log(n)      #FB
  cat(sprintf("%11g",c(mod,k,start,it,lk,lk-lko,max(abs(par-paro)))),"\n",sep=" | ")
  # adjust output
  lk = as.vector(lk)
  dimnames(Pi)=list(state=1:k,state=1:k,time=1:TT)
  if(r==1) dimnames(Mu) = list(item=1,state=1:k) else dimnames(Mu)=list(item=1:r,state=1:k)
  dimnames(Si)=list(item=1:r,item=1:r)
  out = list(lk=lk,piv=piv,Pi=Pi,Mu=Mu,Si=Si,np=np,k = k,aic=aic,bic=bic,lkv=lkv,V=V, n = n, TT = TT, modBasic = mod )
  if(miss) out$Y = Y
  if(out_se){
    seMu = matrix(seMu,r,k)
    seSi2 = matrix(0,r,r)
    seSi2[upper.tri(seSi2,TRUE)]=seSi
    seSi2 = seSi2+t(seSi2-diag(diag(seSi2)))
    seSi = seSi2
    sePi0 = sePi
    sePi = array(0,c(k,k,TT))
    if(mod>1){
      sePi0 = array(sePi0,c(k,k,2))
      sePi0 = aperm(sePi0,c(2,1,3))
      sePi[,,2:mod] = sePi0[,,1]
      sePi[,,(mod+1):TT] = sePi0[,,2]
    } else {
      sePi[,,2:TT] = sePi0
      sePi = aperm(sePi,c(2,1,3))
    }
    dimnames(sePi) = list(state=1:k,state=1:k,time=1:TT)
    if(r==1) dimnames(seMu) = list(item=1,state=1:k) else dimnames(seMu)=list(item=1:r,state=1:k)

    out$sepiv = sepiv
    out$sePi = sePi
    out$seMu = seMu
    out$seSi = seSi
  }
  cat("------------|-------------|-------------|-------------|-------------|-------------|-------------|\n");
  class(out)="LMbasiccont"
  return(out)
}
