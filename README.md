
<!-- README.md is generated from README.Rmd. Please edit that file -->

# basksim

<!-- badges: start -->

[![R-CMD-check](https://github.com/sabrinaschmitt/basksim/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sabrinaschmitt/basksim/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/sabrinaschmitt/basksim/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/sabrinaschmitt/basksim/actions/workflows/test-coverage.yaml)
<!-- badges: end -->

## Overview

`basksim` calculates the operating characteristics of different basket
trial designs based on simulation.

## Installation

Install the development version with:

``` r
# install.packages("devtools")
devtools::install_github("sabrinaschmitt/basksim")
```

## Usage

With `basksim` you can calculate the operating characteristics such as
rejection probabilities and mean squared error of single-stage basket
trials with different designs.

At first, you have to create a design-object using a setup-function. For
example to create a design-object for Fujikawa’s design (Fujikawa et
al., 2020):

``` r
library(basksim)
design <- setup_fujikawa(k = 3, shape1 = 1, shape2 = 1, p0 = 0.2)
```

`k` is the number of baskets, `shape1` and `shape2` are the shape
parameters of the Beta-prior of the response probabilities of each
baskets and `p0` is the response probability that defines the null
hypothesis.

Use `get_details` to estimate several important operating
characteristics:

``` r
get_details(
  design = design,
  n = c(15, 20, 25),
  p1 = c(0.2, 0.5, 0.5),
  lambda = 0.95,
  epsilon = 1.5,
  tau = 0,
  iter = 5000
)

# $Rejection_Probabilities
# [1] 0.4012 0.9780 0.9876
# 
# $FWER
# [1] 0.4012
# 
# $Mean
# [1] 0.2990107 0.4814856 0.4841056
# 
# $MSE
# [1] 0.020201723 0.007759721 0.006991584
# 
# $Lower_CL
# [1] 0.1509890 0.3401165 0.3445177
# 
# $Upper_CL
# [1] 0.4576028 0.6231458 0.6239504
```
