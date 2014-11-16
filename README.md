Moses-for-Mere-Mortals
======================
**Machine translation for the real world**

Set of Linux bash scripts that, together, create a **basic translation chain prototype** able of processing **very large corpora**. It uses **Moses**, a widely known statistical machine translation system. 

The idea is to help build a translation chain for the real world, but it should also enable a quick evaluation of Moses for actual translation work and guide users in their first steps of  using Moses. 

If you want to use the latest stable and tested version of Moses for Mere Mortals, just download the tar.gz files in the https://github.com/jladcr/Moses-for-Mere-Mortals/tree/master/Downloadable_Versions page.

A **Tutorial** and a **demonstration corpus** (too small for doing justice to the qualitative results that can be achieved with Moses, but able of giving a realistic view of the relative duration of the steps involved) are available. 

Two Windows add-ins allow the creation of Moses input files from `*`.TMX translation memories (Extract_TMX_Corpus.exe), as well as the creation of `*`.TMX files from Moses output files (Moses2TMX.exe). A **synergy between machine translation and translation memories** is therefore created.

Moses for Mere Mortals (MMM) has been tested with the following 64 bit (AMD64) Linux distributions:

  * Ubuntu 14.04
  * Ubuntu 12.04

Documents used for corpora training should be perfectly aligned and saved in **UTF-8** character encoding. Documents to be translated should also be in UTF-8 format. One would expect the users of these scripts, perhaps after having tried the provided demonstration corpus, to immediately use and get results with the real corpora they are interested in.

Moses for Mere Mortals has been **tested and used in a professional translation context**.


