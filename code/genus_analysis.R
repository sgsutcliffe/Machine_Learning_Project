library(tidyverse)

#From the raw-data we will look at the shared file rows are the different samples and columns are the different OTUs
#Cells are the abundance

#Note I named my 'raw data' folder differently

shared <- read_tsv("raw_data-0.3/baxter.subsample.shared", col_types = cols(Group = col_character(), .default = col_double())) %>%
  rename_all(tolower) %>%
  select(group, starts_with("otu")) %>%
  pivot_longer(-group, names_to="otu", values_to="count")
#This is the abundance per OTU per group

#Lesson learned: R doesn't like wide dataframes it prefers long dataframes. That it explains things I have done in the past without knowing it

#With the read_tsv, we're turning Group column into a character (default was double)
#Giving the datatypes speeds things up
#Clean up step (personal preference) going to make the column names lower case
#Add a select to keep group column and remove label, and numotus
#Next we are going to make it in the long format, and use pivot longer all columns except group column (R likes this!)

taxonomy <- read_tsv("raw_data-0.3/baxter.cons.taxonomy") %>%
  rename_all(tolower) %>%
  select(otu, taxonomy) %>%
  #Mutate to change columns to lower otus to lowercas to match the 'shared' file.
  mutate(otu = tolower(otu),
         #Next thing clean taxonomy to get genus level names.
         #Here we use regex to remove the (100) which tells the percentage of the OTU had that classification         
         taxonomy = str_replace_all(taxonomy, "\\(\\d+\\)", ""),
         taxonomy = str_replace(taxonomy, ";unclassified", "_unclassified"),
         taxonomy = str_replace_all(taxonomy, ";unclassified", ""),
         taxonomy = str_replace_all(taxonomy, ";$", ""),
         taxonomy = str_replace_all(taxonomy, ".*;", ""))
         #An issue with this taxonomy in this version of Mothur output is that everything unclassified is labeled unclassified
         #So despite being different Family-level taxa a genus would still get labled 'unclassified' so we want to change that

#Get the metadata
metadata <- read_tsv("raw_data-0.3/baxter.metadata.tsv", col_types=cols(sample = col_character())) %>%
  rename_all(tolower) %>% rename(group = sample) %>%
  #There is a medical condition he is interested in for this data but I don't really understand it. It's fine I think.
  #srn is screen relevant neuplasia or something like that
  #dx_bin has all the diagnosis
  mutate(srn = dx_bin == "Adv Adenoma" | dx_bin == "Cancer", lesion = dx_bin == "Adv Adenoma" | dx_bin == "Cancer" | dx_bin == "Adenoma") 

# Next step is to join the shared and taxonomy dataframes by OTU names thus giving taxonomy to my shared dataframe
composite <- inner_join(shared, taxonomy, by='otu') %>%
  #Now collapse the same taxonomy by the same sample, i.e. sometimes you can have multiple OTUs with the same genus
  group_by(group, taxonomy) %>% summarize(count = sum(count), .groups="drop") %>%
  group_by(group) %>% mutate(rel_abund = count / sum(count)) %>%
  #Now that we have counts per group and per taxonomy we then get the relative abundance in new column
  ungroup() %>%
  select(-count) %>%
  #Removes counts 
  inner_join(., metadata, by="group")
  #Add in the metadat
  
  






