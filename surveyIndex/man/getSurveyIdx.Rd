% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/getSurveyIdx.R
\name{getSurveyIdx}
\alias{getSurveyIdx}
\title{Calculate survey indices by age.}
\usage{
getSurveyIdx(x, ages, myids, kvecP = rep(12 * 12, length(ages)),
  kvecZ = rep(8 * 8, length(ages)), gamma = 1.4, cutOff = 1,
  fam = "Gamma", useBIC = FALSE, nBoot = 1000, mc.cores = 2,
  method = "ML", predD = NULL,
  modelZ = rep("Year+s(lon,lat,k=kvecZ[a],bs='ts')+s(Ship,bs='re',by=dum)+s(Depth,bs='ts')+s(TimeShotHour,bs='cc')",
  length(ages)),
  modelP = rep("Year+s(lon,lat,k=kvecP[a],bs='ts')+s(Ship,bs='re',by=dum)+s(Depth,bs='ts')+s(TimeShotHour,bs='cc')",
  length(ages)), knotsP = NULL, knotsZ = NULL)
}
\arguments{
\item{x}{DATRASraw object}

\item{ages}{vector of ages}

\item{myids}{haul.ids for grid}

\item{kvecP}{vector with spatial smoother max. basis dimension for each age group, strictly positive part of model}

\item{kvecZ}{vector with spatial smoother max. basis dimension for each age group, presence/absence part of model}

\item{gamma}{model degress of freedom inflation factor (see 'gamma' argument to gam() )}

\item{cutOff}{treat observations below this value as zero}

\item{fam}{distribution, either "Gamma" or "LogNormal".}

\item{useBIC}{use BIC for smoothness selection (overrides 'gamma' argument)}

\item{nBoot}{number of bootstrap samples used for calculating index confidence intervals}

\item{mc.cores}{number of cores for parallel processing}

\item{method}{smoothness selection method used by 'gam'}

\item{predD}{optional DATRASraw object, defaults to NULL. If not null this is used as grid.}

\item{modelZ}{vector of model formulae for presence/absence part, one pr. age group}

\item{modelP}{vector of model formulae for strictly positive repsonses, one pr. age group}

\item{knotsP}{optional list of knots to gam, strictly positive repsonses}

\item{knotsZ}{optional list of knots to gam, presence/absence}
}
\value{
A survey index (list)
}
\description{
Calculate survey indices by age.
}
\details{
This is based on the methods described in
Berg et al. (2014): "Evaluation of alternative age-based methods for estimating relativeabundance from survey data in relation to assessment models",
Fisheries Research 151(2014) 91-99.
}
\examples{
library(surveyIndex)
##downloadExchange("NS-IBTS",1994:2014)
dAll<-readExchangeDir(".",strict=FALSE)
mc.cores<-2; library(parallel)
d<-subset(dAll, Species=="Pollachius virens",Quarter==1,HaulVal=="V",StdSpecRecCode==1, Gear=="GOV")
dAll<-NULL; gc(); ## lose dAll because it takes up a lot of memory
d<-addSpectrum(d,by=1)
## get idea about number of age groups to include
agetab<-xtabs(NoAtALK~Year+Age,data=d[[1]])
agetab.df<-as.data.frame(agetab)
ages<-1:8
## require at least 1 aged individual in each year
for(a in ages){
    if(any(agetab.df$Freq[agetab.df$Age==a]<1))
        d<-fixAgeGroup(d,age=a,fun=ifelse(a==min(ages),"min","mean"))
}
d<-subset(d,Age>=min(ages))

###############################
## Convert to numbers-at-age
###############################
d.ysplit <- split(d, d$Year)
ALK<-mclapply(d.ysplit,fitALK,minAge=min(ages),maxAge=max(ages),autoChooseK=TRUE,useBIC=TRUE,varCof=FALSE,maxK=50,mc.cores=mc.cores)
Nage<-mclapply(ALK,predict,mc.cores=mc.cores)
for(i in 1:length(ALK)) d.ysplit[[i]]$Nage=Nage[[i]];
dd <- do.call("c",d.ysplit)

##############
## Fit model
##############
grid <- getGrid(dd, nLon=40)
## set max basis dim for spatial smooths by age, P=positive and Z=zero/absence.
## These are set relatively low here to speed up the example
kvP <- c(50,50,50,40,30,rep(10,length(ages)-5))
kvZ <- kvP / 2;
mP <- rep("Year+s(lon,lat,k=kvecP[a],bs='ts')+s(Depth,bs='ts',k=6)+offset(log(HaulDur))",length(ages)  );
mZ <- rep("Year+s(lon,lat,k=kvecZ[a],bs='ts')+s(Depth,bs='ts',k=6)+offset(log(HaulDur))",length(ages)  );

SIQ1 <- getSurveyIdx(dd,ages=ages,myids=grid[[3]],cutOff=0.1,kvecP=kvP,kvecZ=kvZ,modelZ=mZ,modelP=mP,mc.cores=mc.cores) ## if errors are encountered, debug with mc.cores=1

strat.mean<-getSurveyIdxStratMean(dd,ages)

## plot indices, distribution map, and estimated depth effects
surveyIdxPlots(SIQ1,dd,cols=ages,alt.idx=strat.mean,grid[[3]],par=list(mfrow=c(3,3)),legend=FALSE,select="index",plotByAge=FALSE)

surveyIdxPlots(SIQ1,dd,cols=ages,alt.idx=NULL,grid[[3]],par=list(mfrow=c(3,3)),legend=FALSE,colors=rev(heat.colors(8)),select="map",plotByAge=FALSE)

surveyIdxPlots(SIQ1,dd,cols=ages,alt.idx=NULL,grid[[3]],par=list(mfrow=c(3,3)),legend=FALSE,select="2",plotByAge=FALSE)


## Calculate internal concistency and export to file
internalCons(SIQ1$idx)
exportSI(SIQ1$idx,ages=ages,years=levels(dd$Year),toy=mean(dd$timeOfYear),file="out.dat",nam="Survey index demo example")
}
\author{
Casper W. Berg
}

