#Quick Start Guide v.2.1

This guide has 19 steps to install Moses for Mere Mortals and translate and score a document with the default values on a new computer. Refer to the Tutorial.docx for detailed instructions, including how to change the defaults. During the installation, the prompt will change. In what follows, it is indicated in _italic_. This italic text (and the space that follows it) should not be entered in the Terminal. 

**Hint 1**: search and replace "{username}" by your username in this file . Like this, you will be able to copy and paste the instructions that follow.

**Hint 2**: instead of typing the `instructions` that follow, just copy and paste them in the Terminal.
___
###Install Moses for Mere Mortals 
1. Open the Terminal.

2. Create the Machine-Translation directory:

  _~$_ `mkdir /home/{username}/Desktop/Machine-Translation` [Enter] (“{username}” is your Linux userid)
  
3. Download the latest Moses-for-Mere-Mortals (MMM) release (e.g., 1.24) to /home/{username}/Desktop/Machine-Translation:

  _~$_ `cd /home/{username}/Desktop/Machine-Translation` [Enter]
  
  _~/Desktop/Machine-Translation$_ `wget https://github.com/jladcr/Moses-for-Mere-Mortals/archive/v1.24.tar.gz` [Enter]
  
4. Extract the latest MMM release:
 
  _~/Desktop/Machine-Translation$_ `tar xvf /home/{username}/Desktop/Machine-Translation/v1.24.tar.gz` [Enter]
  
5. Move the contents of the directory just created and erase it as well as the tar.gz file:

  _~/Desktop/Machine-Translation$_ `mkdir /home/{username}/Desktop/Machine-Translation/Moses-for-Mere-Mortals` [Enter]
  
  _~/Desktop/Machine-Translation$_ `mv /home/{username}/Desktop/Machine-Translation/Moses-for-Mere-Mortals-1.24/* /home/{username}/Desktop/Machine-Translation/Moses-for-Mere-Mortals` [Enter]
  
  _~/Desktop/Machine-Translation$_ `rm -rf /home/{username}/Desktop/Machine-Translation/Moses-for-Mere-Mortals-1.24/` [Enter]
  
  _~/Desktop/Machine-Translation$_ `rm -f /home/{username}/Desktop/Machine-Translation/v1.24.tar.gz` [Enter]
   
6. Change to the Moses for Mere Mortals scripts directory:

  _~/Desktop/Machine-Translation$_ `cd /home/{username}/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts` [Enter]
  
7. Install dependencies (copy to the Terminal just what follows the prompt, which is in this case “~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$ “):

  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `./install-0.51` [Enter]
  
8. Build (create) the main Moses for Mere Mortals products:

  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `./create-1.44` [Enter]
___  
###Train translation model 
9. Prepare the training corpus (this step should be omitted if you are using the default values of the scripts): 

  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `./make-test-files-0.28` [Enter]
   
10. Train the translation model:

  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `./train-1.23` [Enter]
  
11. Wait for training to finish. (Over 3 hours on Intel i7 720-QM processor with 8 GB RAM)
___
###Translate a document
12. Find the filename of the new log (the exact name will be different from that below):
 
  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `ls ~/Machine-Translation/Moses-MMM/reports/train` [Enter]
  
  The name will be similar to the following one:
  
    pt-en.C-100-60-1.LM-800-new.MM-1.day-26-10-14-time-01-02-19.report
    
13. Use an editor such as gedit to add the log's filename to the line starting with “logfile=”:
 
  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `gedit ./translate-1.39` [Enter]
  
  Look for "logfile=" and insert there the name that you found in step 11:
  
    logfile=pt-en.C-800-new.for_train-60-1.LM-800-new.MM-1.day-26-10-14-time-01-02-19.report
    
14. Save the change and exit the editor.

15. Translate a document:
 
  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `./translate-1.39` [Enter]
  
16. Review the translation output: 

  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `gedit ~/Desktop/Machine-Translation/Moses-MMM/translation_output/100.pt.en.moses` [Enter]
___  
###Score the translation (compare it with a human translation)
17. Evaluate the translation:
 
  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `./score-0.90` [Enter]
  
18. Get the name of the score report file (the exact name will be different from that below):
 
  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `ls ~/Desktop/Machine-Translation/Moses-MMM/translation_scoring` [Enter] 

  The name will be similar to the following one:

    100-BLEU-0.6063-NIST-8.1554-12-07-2010-pt-en.F-0-R-1-T-1.L-1 
    
19. Review the evaluation output: 

  _~/Desktop/Machine-Translation/Moses-for-Mere-Mortals/scripts$_ `gedit ~/Desktop/Machine-Translation/Moses-MMM/translation_scoring/100-BLEU-0.6063-NIST-8.1554-12-07-2010-pt-en.F-0-R-1-T-1.L-1` [Enter] 

_Special thanks to Tom Hoar for consolidating the previous documentation into the very first version of this Quick-Start-Guide.docx to help users to get up to speed very quickly._
