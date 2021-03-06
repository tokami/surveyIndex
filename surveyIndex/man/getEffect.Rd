% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/getEffect.R
\name{getEffect}
\alias{getEffect}
\title{Calculate confidence intervals for a named parameter in a survey index model.}
\usage{
getEffect(x, dat, parName = "Gear", cutOff, nboot = 1000, pOnly = FALSE)
}
\arguments{
\item{x}{survey index}

\item{dat}{DATRASraw object}

\item{parName}{name of the parameter, e.g. "Gear"}

\item{cutOff}{see getSurveyIndex()}

\item{nboot}{see getSurveyIndex()}

\item{pOnly}{only calculate for positive part of model, defaults to FALSE.}
}
\value{
list of estimates + ci bounds for each age group.
}
\description{
Calculate confidence intervals for a named parameter in a survey index model.
}
\details{
.. content for \details{} ..
}

