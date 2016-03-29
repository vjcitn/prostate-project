#' Prep files for RJAGS
#'
#' @param pt.data filled dataframe
#' @param psa.data filled dataframe
#' @param bx.data filled dataframe
#' @return list for RJAGS prep
#' @export
#'
#'
#' WORKFLOW
#' 0. Load packageges and  necessary data.
#' 1. Format pt-level data for JAGS run
#' 2. Format PSA data for JAGS run
#' 3. Format biopsy data for JAGS run
#' THEN
#' 0. Load libraries
#' 1. Define data to be sent to jags function
#' 2. Initialize model parameters
#' 3. Define parameters to be tracked
#' 4. Define other jags settings?
#' 5. Write model definition?
#'
#'
RJAGSprep <- function(all = all) { #default file names
  pt.data <- all[[1]]
  psa.data <- all[[2]]
  bx.full <- all[[3]]
  ### 0. Load packageges and  necessary data.

  #These packages should be loaded automatically when someone loads our package

  library("lme4")
  library("splines")


  ### 1. Format pt-level data for JAGS run

  (n<-dim(pt.data)[1]) #there are 1000 patients.
  #I think you have already defined this in your data shaping code, so you wouldn't need to define it again
  #(The same may be true of other variables I define below. If that is the case, no need to define them again. I won't keep putting this reminder in the code every place this may happen.)

  #define vector with observed cancer state for patients with surgery
  eta_data<-pt.data$true.gs[!is.na(pt.data$true.gs)]


  #number of patients with true state (eta) observed
  (n_eta_known<-length(eta_data))  #203

  #Pt.data should already be ordered so that those with eta=0, 1 come before patients without eta observed (true.gs=NA) and subject ids 1:n_eta_known are the ids for patients with eta observed


  #I also found something that should have been included in the pt.data shaping earlier.
  #pt.data$rc<-rep(0,n)
  #for(i in 1:n){
  #  if(max(bx.full$rc[bx.full$subj==i], na.rm=T)==1){pt.data$rc[i]<-1}}
  #Pt.data needs to be ordered by subject to run this line as is. Otherwise, try if(max(bx.full$rc[bx.full$id==pt.data$id[i]], na.rm=T)==1){pt.data$rc[i]<-1}

  table(pt.data$rc) #205 patients with grade reclassification observed




  ### 2. Format PSA data for JAGS run
  (n_obs_psa<-dim(psa.data)[1]) #18792 #the total number of PSA observations
  Y<-psa.data$log_psa #name log-PSA observatios "Y
  subj_psa<-psa.data$subj #vector with subject ids that correspond to PSA obsrevations

  #matrix of covariates with "random effects" (This term is familiar to stats people, but may not be familiar to you. Make sure to keep the Z_ and X_ labels here, because stats people will understand that better.)
  #here, intercept and age (standardized)
  psa.data$age.std<-scale(psa.data$age) #you may want to move this line to original data shaping function
  Z_data<-as.matrix( cbind(rep(1,n_obs_psa), psa.data$age.std) )
  (d_Z<-dim(Z_data)[2]) #should be 2


  #matrix of covariates with only fixed effects
  #here, prostate volume (standardized on patient-level with mean and std of volume since it is constant within patients). no intercept needed
  psa.data$vol.std<-scale(psa.data$vol.avg, center=mean(pt.data$vol.avg), scale=sd(pt.data$vol.avg)) #you may want to move this line to original data shaping
  X_data<-as.matrix(cbind(psa.data$vol.std))
  (d_X<-dim(X_data)[2]) #should be 1


  #here, I fit a linear mixed effects regression (lmer) to get a starting value for the covariance parameter. I will use this as input for the JAGS model
  #lmer fit to get starting value for covariance parameter in JAGS
  mod_lmer<-lmer(log.psa~ vol.std + (1+ age.std |id), data=psa.data)
  (var_vec <- apply(coef(mod_lmer)$id, 2, var)[1:d_Z])
  (var_vec <- c(var_vec[2], var_vec[1])) #I want the covariance parameters ordered so that the one corresponding to the intercept is first and the one corresponding to age is second. I don't know why the model output is in a different order






  ### 3. Format biopsy data for JAGS run
  #Here, we define the outcome and predictors for grade reclassification on biopsy
  #Later, we will add two additional models here: one for biopsy received and one for surgery
  rc.data<-bx.full[bx.full$bx.here==1 & !is.na(bx.full$bx.here),]
  (n_rc<-dim(rc.data)[1]) #4134
  RC<-as.numeric(rc.data$rc) #indicator of reclassificaiton in this interval
  subj_rc<-rc.data$subj

  #covariate matrix include an intercept, natural spline representations of time and calendar date (df=2 for each), and mean- and sd- standardized age
  V_RC_data<-as.matrix(cbind(rep(1,n_rc), ns(rc.data$bx.time, 2), ns(rc.data$bx.date.num, 2), scale(rc.data$bx.age) ))
  (d_V_RC<-dim(V_RC_data)[2]) #should be 6


  #cat("test")
  ### FINISHED DATA PREP, NOW ARGUMENT PREP
  #' 0. Load libraries
  #' 1. Define data to be sent to jags function
  #' 2. Initialize model parameters
  #' 3. Define parameters to be tracked
  #' 4. Define other jags settings?
  #' 5. Write model definition?


  ### 0. Load libraries
  #These packages should be loaded automatically when someone loads our package

  library("bayesm")





  ### 1. Define data to be sent to jags function

  #The number of latent classes/ values of true cancer state
  K<-2
  #We've written this initial code only to handle a binary latent class. This might be something to extend later. (I have a code for ordered latent classes, but I don't know how much more complicated that will be to package)


  jags_data<-list(K=K, n=n, eta_data=eta_data, n_eta_known=n_eta_known, n_obs_psa=n_obs_psa, Y=Y, subj_psa=subj_psa, Z=Z_data, X=X_data, d_Z=d_Z, d_X=d_X, I_d_Z=diag(d_Z), RC=RC, n_rc=n_rc, subj_rc=subj_rc, V_RC=V_RC_data, d_V_RC=d_V_RC)

  names(pt.data)

  ### 2. Initialize model parameters
  inits <- function(){

    p_eta<-rbeta(1,1,1)

    eta_hat<-pt.data$rc[is.na(pt.data$true.gs)]

    xi<-c(min(rlnorm(1),100), min(rlnorm(1),100))
    mu_raw<-as.matrix(cbind(rnorm(d_Z),rnorm(d_Z)))
    Tau_B_raw<-rwishart((d_Z+1),diag(d_Z)*var_vec)$W
    sigma_res<-min(rlnorm(1),1)

    beta<-rnorm(d_X)

    gamma_RC<-rnorm((d_V_RC+1), mean=0, sd=0.1)  #last coefficient is effect of eta=1

    list(p_eta=p_eta, eta_hat=eta_hat, xi=xi, mu_raw=mu_raw, Tau_B_raw=Tau_B_raw, sigma_res=sigma_res, beta=beta,  gamma_RC=gamma_RC)
  }



  ### 3. Define parameters to be tracked
  parameters.to.save <- c("p_eta", "eta_hat", "mu_int", "mu_slope", "sigma_int", "sigma_slope", "sigma_res", "rho_int_slope", "cov_int_slope", "b_vec", "beta",  "gamma_RC",  "p_rc")


  ### 4. Define other jags settings?
  # It is probably easier to let users define these settings themselves.

  # change length; burn-in; number thinned; number of chains
  #n.iter <- 50000; n.burnin <- 25000; n.thin <- 20; n.chains <- 1




  ### 5. Write model definition?
  #When running JAGS, it is also necessary to provide a .txt file that defines the model. The most straight forward thing to do at this point is to assume that users want to run the *exact* model I've already defined. In that case, we just need to provide this text file in the R package. Or, if it is not possible to include a .txt file, we can include an R script that writes the .txt file. I will send both to you.


  ### What this code should enable/ Next steps for users
  #This function should return the following objects (that will then serves as arguments for the JAGS function): jags_data, inits, parameters.to.save, a model file ("UNADJ-jags-model.txt").

  #Users would then load the library R2jags and execute the following command:
  #jags(data=jags_data, inits=inits, parameters.to.save=parameters.to.save, model.file="UNADJ-jags-model.txt", n.chains, n.iter, n.burnin, n.thin)



  #I ran the code below to make sure that this code version works!
  #ex.jags<-jags(data=jags_data, inits=inits, parameters.to.save=parameters.to.save, model.file="UNADJ-jags-model.txt", n.chains=1, n.iter=50, n.burnin=10, n.thin=5)

  #ex.out<-ex.jags$BUGSoutput

  #str(ex.out$sims.list)

  return(jags_data)
}
