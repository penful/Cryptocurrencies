<h2 align="center">Exploring the dependencies among main cryptocurrency log‐returns: A hidden Markov model </h2>

<h5 align="center">**Fulvia Pennoni** &middot; **Francesco Bartolucci** &middot; **Gianfranco Forte** &middot; **Ferdinando Ametrano**</h5>

<br>

<h4>Overview</h4>

This repository contains the <tt>R</tt> functions to show an example of maximum likelihood estimation of the parameters of the hidden Markov (HM) model proposed in the paper. 

---

<h4>Description of the content</h4>

The repository contains:

- the functions used to perform maximum likelihood estimation of model parameters in particular:
  - the functions <tt>lmestCont.R</tt>, and <tt>lmbasic.cont.R</tt> contain the code to run the EM algorithm;
- the remaining functions serve as auxiliary functions;
- a dataset is used to show an example with three simulated log-returns in the file is named <tt>data.RData</tt>, 
- the  example to run is in the file <tt>crypto_code.R</tt>.

---

<h4>Usage</h4>


    The general model formulation is that of the functions in the R package LMest. See this package for input and output details.



