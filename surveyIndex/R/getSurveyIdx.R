##' Calculate survey indices by age.
##'
##' This is based on the methods described in
##' Berg et al. (2014): "Evaluation of alternative age-based methods for estimating relativeabundance from survey data in relation to assessment models",
##' Fisheries Research 151(2014) 91-99.
##' @title Calculate survey indices by age.
##' @param x DATRASraw object
##' @param ages vector of ages
##' @param myids haul.ids for grid
##' @param kvecP vector with spatial smoother max. basis dimension for each age group, strictly positive part of model 
##' @param kvecZ vector with spatial smoother max. basis dimension for each age group, presence/absence part of model 
##' @param gamma model degress of freedom inflation factor (see 'gamma' argument to gam() ) 
##' @param cutOff treat observations below this value as zero
##' @param fam distribution, either "Gamma" or "LogNormal".
##' @param useBIC use BIC for smoothness selection (overrides 'gamma' argument)
##' @param nBoot number of bootstrap samples used for calculating index confidence intervals
##' @param mc.cores number of cores for parallel processing
##' @param method smoothness selection method used by 'gam'
##' @param predD optional DATRASraw object, defaults to NULL. If not null this is used as grid.
##' @param modelZ vector of model formulae for presence/absence part, one pr. age group
##' @param modelP vector of model formulae for strictly positive repsonses, one pr. age group
##' @param knotsP optional list of knots to gam, strictly positive repsonses
##' @param knotsZ optional list of knots to gam, presence/absence
##' @return A survey index (list)
##' @author Casper W. Berg
##' @export
##' @examples
##' library(surveyIndex)
##' ##downloadExchange("NS-IBTS",1994:2014)
##' dAll<-readExchangeDir(".",strict=FALSE)
##' mc.cores<-2; library(parallel)
##' d<-subset(dAll, Species=="Pollachius virens",Quarter==1,HaulVal=="V",StdSpecRecCode==1, Gear=="GOV")
##' dAll<-NULL; gc(); ## lose dAll because it takes up a lot of memory
##' d<-addSpectrum(d,by=1)
##' ## get idea about number of age groups to include
##' agetab<-xtabs(NoAtALK~Year+Age,data=d[[1]])
##' agetab.df<-as.data.frame(agetab)
##' ages<-1:8
##' ## require at least 1 aged individual in each year
##' for(a in ages){
##'     if(any(agetab.df$Freq[agetab.df$Age==a]<1))
##'         d<-fixAgeGroup(d,age=a,fun=ifelse(a==min(ages),"min","mean"))
##' }
##' d<-subset(d,Age>=min(ages))
##' 
##' ###############################
##' ## Convert to numbers-at-age
##' ###############################
##' d.ysplit <- split(d, d$Year)
##' ALK<-mclapply(d.ysplit,fitALK,minAge=min(ages),maxAge=max(ages),autoChooseK=TRUE,useBIC=TRUE,varCof=FALSE,maxK=50,mc.cores=mc.cores)
##' Nage<-mclapply(ALK,predict,mc.cores=mc.cores)
##' for(i in 1:length(ALK)) d.ysplit[[i]]$Nage=Nage[[i]];
##' dd <- do.call("c",d.ysplit)
##' 
##' ##############
##' ## Fit model
##' ##############
##' grid <- getGrid(dd, nLon=40)
##' ## set max basis dim for spatial smooths by age, P=positive and Z=zero/absence.
##' ## These are set relatively low here to speed up the example
##' kvP <- c(50,50,50,40,30,rep(10,length(ages)-5))
##' kvZ <- kvP / 2;
##' mP <- rep("Year+s(lon,lat,k=kvecP[a],bs='ts')+s(Depth,bs='ts',k=6)+offset(log(HaulDur))",length(ages)  );
##' mZ <- rep("Year+s(lon,lat,k=kvecZ[a],bs='ts')+s(Depth,bs='ts',k=6)+offset(log(HaulDur))",length(ages)  );
##' 
##' SIQ1 <- getSurveyIdx(dd,ages=ages,myids=grid[[3]],cutOff=0.1,kvecP=kvP,kvecZ=kvZ,modelZ=mZ,modelP=mP,mc.cores=mc.cores) ## if errors are encountered, debug with mc.cores=1 
##' 
##' strat.mean<-getSurveyIdxStratMean(dd,ages)
##' 
##' ## plot indices, distribution map, and estimated depth effects
##' surveyIdxPlots(SIQ1,dd,cols=ages,alt.idx=strat.mean,grid[[3]],par=list(mfrow=c(3,3)),legend=FALSE,select="index",plotByAge=FALSE)
##' 
##' surveyIdxPlots(SIQ1,dd,cols=ages,alt.idx=NULL,grid[[3]],par=list(mfrow=c(3,3)),legend=FALSE,colors=rev(heat.colors(8)),select="map",plotByAge=FALSE)
##' 
##' surveyIdxPlots(SIQ1,dd,cols=ages,alt.idx=NULL,grid[[3]],par=list(mfrow=c(3,3)),legend=FALSE,select="2",plotByAge=FALSE)
##' 
##' 
##' ## Calculate internal concistency and export to file
##' internalCons(SIQ1$idx)
##' exportSI(SIQ1$idx,ages=ages,years=levels(dd$Year),toy=mean(dd$timeOfYear),file="out.dat",nam="Survey index demo example")
getSurveyIdx <-
    function(x,ages,myids,kvecP=rep(12*12,length(ages)),kvecZ=rep(8*8,length(ages)),gamma=1.4,cutOff=1,fam="Gamma",useBIC=FALSE,nBoot=1000,mc.cores=2,method="ML",predD=NULL,
             modelZ=rep("Year+s(lon,lat,k=kvecZ[a],bs='ts')+s(Ship,bs='re',by=dum)+s(Depth,bs='ts')+s(TimeShotHour,bs='cc')",length(ages)  ),modelP=rep("Year+s(lon,lat,k=kvecP[a],bs='ts')+s(Ship,bs='re',by=dum)+s(Depth,bs='ts')+s(TimeShotHour,bs='cc')",length(ages)  ),knotsP=NULL,knotsZ=NULL
             ){
        
        
        if(length(modelP)<length(ages)) stop(" length(modelP) < length(ages)");
        if(length(modelZ)<length(ages)) stop(" length(modelZ) < length(ages)");
        if(length(kvecP)<length(ages)) stop(" length(kvecP) < length(ages)");
        if(length(kvecZ)<length(ages)) stop(" length(kvecZ) < length(ages)");
        if(length(fam)<length(ages)) {famVec = rep(fam[1],length(ages)); warning("length of fam argument less than number of ages, only first element is used\n"); } else famVec=fam;
        
        x[[1]]$Year=as.factor(x[[1]]$Year);
        x[[2]]$Year=as.factor(x[[2]]$Year);
        pModels=list()
        zModels=list()
        gPreds=list() ##last data year's predictions
        gPreds2=list() ## all years predictions
        pData=list()
        require(mgcv)
        require(parallel)
        yearNum=as.numeric(as.character(x$Year));
        yearRange=min(yearNum):max(yearNum);

        gearNames=names(xtabs(~Gear,data=x[[2]]))
        if("GOV" %in% gearNames) { myGear="GOV"; } else {
           myGear=names(xtabs(~Gear,data=x[[2]]))[which.max(xtabs(~Gear,data=x[[2]]))]
           cat("Notice: GOV gear not found. Standard gear chosen to be: ",myGear,"\n");
        }
        
        resMat=matrix(NA,nrow=length(yearRange),ncol=length(ages));
        upMat=resMat;
        loMat=resMat;
        do.one.a<-function(a){
            ddd=x[[2]]; ddd$dum=1.0;
            ddd$A1=ddd$Nage[,a]
            gammaPos=gamma;
            gammaZ=gamma;
            if(useBIC){
                nZ=nrow(ddd);
                nPos=nrow(subset(ddd,A1>cutOff));
                gammaPos=log(nPos)/2;
                gammaZ=log(nZ)/2;
                cat("gammaPos: ",gammaPos," gammaZ: ",gammaZ,"\n");
            }
            pd = subset(ddd,A1>cutOff)
            if(famVec[a]=="LogNormal"){
                f.pos = as.formula( paste( "log(A1) ~",modelP[a]));
                f.0 = as.formula( paste( "A1>",cutOff," ~",modelZ[a]));
                
                print(system.time(tryCatch.W.E(m.pos<-gam(f.pos,data=subset(ddd,A1>cutOff),gamma=gammaPos,method=method,knots=knotsP))$value));

                if(class(m.pos)[2] == "error") {
                    print(m.pos)
                    stop("Error occured for age ", a, " in the positive part of the model\n", "Try reducing the number of age groups or decrease the basis dimension of the smooths, k\n")
                }
                
                print(system.time(m0<-tryCatch.W.E(gam(f.0,gamma=gammaZ,data=ddd,family="binomial",method=method,knots=knotsZ))$value));

                if(class(m0)[2] == "error") {
                    print(m0)
                    stop("Error occured for age ", a, " in the binomial part of the model\n", "Try reducing the number of age groups or decrease the basis dimension of the smooths, k\n")
                }
                
            } else {
                f.pos = as.formula( paste( "A1 ~",modelP[a]));
                f.0 = as.formula( paste( "A1>",cutOff," ~",modelZ[a]));
                
                print(system.time(m.pos<-tryCatch.W.E(gam(f.pos,data=subset(ddd,A1>cutOff),family=Gamma(link="log"),gamma=gammaPos,method=method,knots=knotsP))$value));

                if(class(m.pos)[2] == "error") {
                    print(m.pos)
                    stop("Error occured for age ", a, " in the positive part of the model\n", "Try reducing the number of age groups or decrease the basis dimension of the smooths, k\n")
                }
                
                print(system.time(m0<-tryCatch.W.E(gam(f.0,gamma=gammaZ,data=ddd,family="binomial",method=method,knots=knotsZ))$value));

                if(class(m0)[2] == "error") {
                    print(m0)
                    stop("Error occured for age ", a, " in the binomial part of the model\n", "Try reducing the number of age groups or decrease the basis dimension of the smooths, k\n")
                }
            }
            ## Calculate total log-likelihood
            p0p =(1-predict(m0,type="response"))
            ppos=p0p[ddd$A1>cutOff] 
            p0m1=p0p[ddd$A1<=cutOff]
            if(famVec[a]=="Gamma")  totll=sum(log(p0m1))+sum(log(1-ppos))+logLik(m.pos)[1];
            ## if logNormal model, we must transform til log-likelihood to be able to use AIC
            ## L(y) = prod( dnorm( log y_i, mu_i, sigma^2) * ( 1 / y_i ) ) => logLik(y) = sum( log[dnorm(log y_i, mu_i, sigma^2)]  - log( y_i ) )
            if(famVec[a]=="LogNormal") totll=sum(log(p0m1))+ sum(log(1-ppos)) + logLik(m.pos)[1] - sum(m.pos$y);
            
            if(is.null(predD)) predD=subset(ddd,haul.id %in% myids);
            res=numeric(length(yearRange));
            lores=res;
            upres=res;
            gp2=list()
            for(y in levels(ddd$Year)){ 
                ## take care of years with all zeroes
                if(!any(ddd$A1[ddd$Year==y]>cutOff)){
                    res[which(as.character(yearRange)==y)]=0;
                    upres[which(as.character(yearRange)==y)] = 0;
                    lores[which(as.character(yearRange)==y)] = 0;
                    next;
                }

                ## OBS: effects that should be removed should be included here
                predD$Year=y; predD$dum=0;
                predD$ctime=as.numeric(as.character(y));
                predD$TimeShotHour=mean(ddd$TimeShotHour)
                predD$Ship=names(which.max(summary(ddd$Ship)))
                predD$timeOfYear=mean(ddd$timeOfYear);
                predD$HaulDur=30.0
                
                predD$Gear=myGear;
                p.1=try(predict(m.pos,newdata=predD,newdata.guaranteed=TRUE));
                p.0=try(predict(m0,newdata=predD,type="response",newdata.guaranteed=TRUE));
                ## take care of failing predictions
                if(!is.numeric(p.1) | !is.numeric(p.0)) {
                    res[which(as.character(yearRange)==y)]=0;
                    upres[which(as.character(yearRange)==y)] = 0;
                    lores[which(as.character(yearRange)==y)] = 0;
                    next;
                }
                sig2=m.pos$sig2;
                
                if(famVec[a]=="Gamma") { res[which(as.character(yearRange)==y)] = sum(p.0*exp(p.1)); gPred=p.0*exp(p.1) }
                if(famVec[a]=="LogNormal")  { res[which(as.character(yearRange)==y)] = sum(p.0*exp(p.1+sig2/2)); gPred=p.0*exp(p.1+sig2/2) }
                gp2[[y]]=gPred;
                if(nBoot>10){
                    Xp.1=predict(m.pos,newdata=predD,type="lpmatrix");
                    Xp.0=predict(m0,newdata=predD,type="lpmatrix");
                    library(MASS)
                    brp.1=mvrnorm(n=nBoot,coef(m.pos),m.pos$Vp);
                    brp.0=mvrnorm(n=nBoot,coef(m0),m0$Vp);
                    ilogit<-function(x) 1/(1+exp(-x));

                    
                    OS.pos = matrix(0,nrow(predD),nBoot);
                    OS0 = matrix(0,nrow(predD),nBoot);
                    terms.pos=terms(m.pos)
                    terms.0=terms(m0)
                    if(!is.null(m.pos$offset)){
                        off.num.pos <- attr(terms.pos, "offset")
                        
                        for (i in off.num.pos) OS.pos <- OS.pos + eval(attr(terms.pos, 
                                                                            "variables")[[i + 1]], predD)
                    }
                    if(!is.null(m0$offset)){
                        off.num.0 <- attr(terms.0, "offset")
                        
                        for (i in off.num.0) OS0 <- OS0 + eval(attr(terms.0, 
                                                                    "variables")[[i + 1]], predD)
                    }
                    
                    rep0=ilogit(Xp.0%*%t(brp.0)+OS0);
                    if(famVec[a]=="LogNormal"){
                        rep1=exp(Xp.1%*%t(brp.1)+sig2/2+OS.pos);
                    } else {
                        rep1=exp(Xp.1%*%t(brp.1)+OS.pos);
                    }
                    idxSamp = colSums(rep0*rep1);
                    upres[which(as.character(yearRange)==y)] = quantile(idxSamp,0.975);
                    lores[which(as.character(yearRange)==y)] = quantile(idxSamp,0.025);
                }
            } ## rof years
            list(res=res,m.pos=m.pos,m0=m0,lo=lores,up=upres,gp=gPred,ll=totll,pd=pd,gp2=gp2);
        }## end do.one
        noAges=length(ages);
        rr=mclapply(1:noAges,do.one.a,mc.cores=mc.cores);
        logl=0;
        for(a in 1:noAges){
            resMat[,a]=rr[[a]]$res;
            zModels[[a]]=rr[[a]]$m0;
            pModels[[a]]=rr[[a]]$m.pos;
            loMat[,a]=rr[[a]]$lo;
            upMat[,a]=rr[[a]]$up;
            gPreds[[a]]=rr[[a]]$gp;
            logl=logl+rr[[a]]$ll
            pData[[a]] = rr[[a]]$pd
            gPreds2[[a]]=rr[[a]]$gp2
        }
        getEdf<-function(m) sum(m$edf)
        totEdf=sum( unlist( lapply(zModels,getEdf))) + sum( unlist( lapply(pModels,getEdf)));
        list(idx=resMat,zModels=zModels,pModels=pModels,lo=loMat,up=upMat,gPreds=gPreds,logLik=logl,edfs=totEdf,pData=pData,gPreds2=gPreds2);
    }
