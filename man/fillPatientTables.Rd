% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fillPatientTables.R
\name{fillPatientTables}
\alias{fillPatientTables}
\title{fillPatientTables}
\usage{
fillPatientTables(demo.data = demo_data, psa.data = psa_data,
  bx.data = bx_data, surg.data = surg_data, IOP = TRUE)
}
\arguments{
\item{demo.data}{Patient-level data. This dataframe should contain one record (row) per patient. Variables (columns) must include a unique identifier (ID) and valid date of birth for each patient.}

\item{psa.data}{PSA data. This dataframe should contain one record per PSA test (per patient). Variables must include patient ID, date of test, and total PSA observed.}

\item{bx.data}{Biopsy data. This dataframe should contain one record per biopsy (per patient). Variables must include patient ID, date of biopsy, indicator of grade reclassication, and prostate volume (if assessed).}

\item{surg.data}{Surgery data. This dataframe should contain one record per surgery performed. Variables must include patient ID, surgery date, and Gleason score (GS) assessed on entire specimen.}

\item{IOP}{TRUE if biopsy and surgery occurences are informative of the underlying GS, FALSE if non-informative.}
}
\value{
List of three dataframes for analysis: pt.data, psa.data, bx.full. See vignette for examples.
}
\description{
Load dataframes from four patient data files generated in the course of Active Surveillance in order to create a list of formatted patient dataframes for analysis. See vignette for required variable names and format.
}

