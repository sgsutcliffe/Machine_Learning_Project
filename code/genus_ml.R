#The cleaning of data is generated here:
source("code/genus_process.R")
library(mikropml)

#composite is the date we will use to run mikropml
#features == columns in dataframe

#looking at bacterial taxonomic features to predict SRN
srn_genus_data <- composite %>%
  select(group, taxonomy, rel_abund, srn) %>% #We've got more metadata then we need for now. Now we want to just look at abundance of bacteria
  pivot_wider(names_from=taxonomy, values_from = rel_abund) %>%
  select(-group) %>%
  mutate(srn = if_else(srn, "srn", "healthy")) %>% #mikropML does not work on TRUE/FALSE data
  select(srn, everything()) #Just makes sure the SRN category is first

#### Run mikropml: Logistic Regression #### 
#Logistic regression is quick to run to start
#We skipped feature importance as this is the first run and still trying to figure out how to make it better

srn_genus_results <- run_ml(srn_genus_data,
                            method="glmnet",
                            outcome_colname = "srn", #What it is trying to predict
                            seed = 19760620, #number of iterations
                            kfold = 5, #Default 5 fold cross validation
                            cv_times = 100, #Default
                            training_frac = 0.8) #Default

#### Video 6 Preprocessing data ####

#Here we revisit the composite data frame as with the srn_genus_data dataframe we just have relative abundance of each genus and health status but this
#just a few of the features.

composite

#composite has 21 different potential features (including taxa by genus and relative abundance)
#So we will add it other columns to see how things go differently

practise_prepros <- composite %>%
  select(group, fit_result, site, gender, srn, weight) %>% #fit result: continuous variable, site: categorical variable where the samples were collected, 
  distinct() %>%
  mutate(weight = na_if(weight, 0)) %>% #He knew there were some individuals for which no weight was collected and instead a zero was put in, which is wrong. Always check your data! summary()
  select(-group) #don't need in the model

#Here we will test the preprocess_data() 
preprocess_data(practise_prepros, outcome_colname = "srn") -> preprocessed_comp

#Turns out U of michigan site is not important

summary(preprocessed_comp$dat_transformed) 

#What this tells us
# - for conintuous variables (fit_result and weight) it does a scaling and centering, centering means it makes the mean for all the values zero, and scales thaat 1 is sone STD above the mean and -1 one STD below the mean
# - missing data adds in median values (e.g. weight)

#Next removing columns that are perfectly coorelated with each other

#This is the grp_feats

practise_prepros <- composite %>%
  select(group, fit_result, site, gender, srn, weight) %>% 
  distinct() %>%
  mutate(weight = na_if(weight, 0)) %>% 
  select(-group) %>%
  mutate(perfect_corr = fit_result)

# cor(practise_prepros$fit_result, practice_prepros$perfect_corr) == 1

preprocess_data(practise_prepros, outcome_colname = "srn")

#Now lets do it with the SRN_genus_data

preprocess_data(srn_genus_data, outcome_colname = "srn")$dat_transformed -> preprocessed_genus_data
preprocess_data_results <- run_ml(preprocessed_genus_data,
       method="glmnet",
       outcome_colname = "srn", #What it is trying to predict
       seed = 19760620, #number of iterations
       kfold = 5, #Default 5 fold cross validation
       cv_times = 100, #Default
       training_frac = 0.8) #Default

