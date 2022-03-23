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
run_ml(srn_genus_data,
       method="glmnet",
       outcome_colname = "srn", #What it is trying to predict
       seed = 19760620) #Iterations


