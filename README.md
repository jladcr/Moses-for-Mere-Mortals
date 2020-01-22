# Moses-for-Mere-Mortals: Machine translation for the real world 
**THIS SITE IS NO LONGER SUPPORTED. IT WAS BRIEFLY A COMPONENT OF MOSES SMT AND ITS AUTHORS WERE PART OF THE MOSES SMT DEVELOPMENT TEAM. IT WAS NICE WHILE IT LASTED, BUT THE TEAM NO LONGER EXISTS AND THE SOFTWARE HASN'T BEEN UPDATED FOR SEVERAL YEARS. IT IS THEREFORE APPROPRIATE TO SIGNAL THAT THE PROJECT HAS ENDED.**
---
*Please use the https://github.com/jladcr/Moses-for-Mere-Mortals/releases link to download the latest stable release.*

Set of Linux bash scripts that, together, create a **basic translation chain prototype** able of processing **very large corpora**. It uses **Moses**, a widely known statistical machine translation (SMT) system. 

The idea is to help build a translation chain for the real world, but it should also enable a quick evaluation of Moses for actual translation work and guide users in their first steps of  using Moses. 

A **Tutorial** and a **demonstration corpus** (too small for doing justice to the qualitative results that can be achieved with Moses, but able of giving a realistic view of the relative duration of the steps involved) are available. 
Moses for Mere Mortals has been **tested and used in a professional translation context**.


If you want to use the latest stable and tested version of Moses for Mere Mortals, just click the **Releases** button at the top of this page and choose the release you are interested in. Moses for Mere Mortals is to be run on an Ubuntu environment. The Windows addins should be installed and run in Microsoft Windows.

Moses for Mere Mortals (MMM) has been tested with the following 64 bit (AMD64) Linux distributions:

  * Ubuntu 14.04
  * Ubuntu 12.04

Documents used for corpora training should be perfectly aligned and saved in **UTF-8** character encoding. Documents to be translated should also be in UTF-8 format. One would expect the users of these scripts, perhaps after having tried the provided demonstration corpus, to immediately use and get results with the real corpora they are interested in.

The two Windows add-ins allow the creation of Moses input files from `*`.TMX translation memories (Extract_TMX_Corpus.exe), as well as the creation of `*`.TMX files from Moses output files (Moses2TMX.exe). A **synergy between machine translation and translation memories** is therefore created.



