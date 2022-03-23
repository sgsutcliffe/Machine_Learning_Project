##### Third Video in ML series CC122 ####

#The cleaning of data is generated here:
source("code/genus_process.R")

#If you want to move faster you can also load in the datatable by uncommenting this
#composite <- read_tsv("processed_data/composite.tsv")

#Goal to find which genus might be associated with Screen Relevant Neoplasia (SRN)
#Spoiler alert: When we look for one species of bacteria that is significantly different in individuals with SRN we find they're often absent in majority of the population
#Wilcox-test
#Also if we try and make a model using one bacteria as a biomarker and compare it to currently used biomarker (FIT test) they perform poorly.
#This analysis is simply the setup to show that we need to look at multiple-bacteria simultaneously to make a good prediction of SRN using bacteria


#Wilcoxon signed-rank test: Non-parametric Statisitcal hypothesis test to compare the two populations using a set of matched samples
#Individuals with or without SRN, two groups

sig_genera <- composite %>%
  nest(data = -taxonomy) %>% #Here we will exclude all data except taxonomy column (genera), and puts metadata into a data column which is a tibble [490 x 20], 490 rows or subjects in a study and 20 columns of metadata
  mutate(test = map(.x=data, ~wilcox.test(rel_abund~srn, data=.x) %>% tidy)) %>% #Mutate allows a new column containing the results of statistical tests, called 'test'. Map will run the function Wilcoxon test
  #The two variables being relative abundance of an OTU and whether or not they have SRN
  #.x ; is the argument name for the wilcox test not the data tibble dataframe
  # The results of the function is the <htest> but that result can be piped
  # tidy command comes from broom package
  # After  tidy command it turns htest into a tibble of 1 x 4
  # Then, after he'll unest to have the full dataframe back. I need to look at this more!
  unnest(test) %>%
  # Unbundled the htest, so you can see that shiny shiny p-value for every genera
  # Then we need to correct for multiple-comparison errors, as we have 300 genera, so about 14 could be false positives
  # There are 36 but some are false-positives
  mutate(p.adjust = p.adjust(p.value, method="BH")) %>%
  filter(p.adjust < 0.05) %>% 
  select(taxonomy, p.adjust)
write.table(sig_genera, file='processed_data/sig_genera.tsv', sep='\t', row.names = FALSE)
  
composite %>%
  inner_join(sig_genera, by="taxonomy") %>%
  mutate(rel_abund = 100 * (rel_abund + 1/20000), taxonomy = str_replace(taxonomy, "(.*)", "*\\1*"), taxonomy = str_replace(taxonomy, "\\*(.*)_unclassified\\*", "Unclassified<br>*\\1*"), srn =factor(srn,levels=c(T,F))) %>%
  ggplot(aes(x=rel_abund, y=taxonomy, color=srn, fill=srn)) +
  geom_jitter(position = position_jitterdodge(dodge.width = 0.8, 
                                              jitter.width = 0.3),
              shape=21) +
  #Ooo jitter plot, that's new for me to, and dodge points, with space
  stat_summary(fun.data =  median_hilow, fun.args = list(conf.int=0.5),
               geom="pointrange", position = position_dodge(width=0.8),
               color="black", show.legend=FALSE) +
               scale_x_log10() +
  scale_color_manual(NULL, 
                     breaks = c(F,T),
                     values = c("gray", "dodgerblue"),
                     labels = c("Healthy", "SRN")) +
  scale_fill_manual(NULL, 
                     breaks = c(F,T),
                     values = c("gray", "dodgerblue"),
                     labels = c("Healthy", "SRN")) +
  labs(x="Relative abundance (%)", y=NULL) +
  theme_classic() +
  theme(axis.text.y = element_markdown())
  #adds stats to the figure, the median value
  #Recall that scale_x_log10 works with stat_summary in this situation because I am using median values. If you were using mean values, you would use
  #coord_trans(x="log10")

ggsave("figures/significant_genera.jpeg", device ="jpeg", width=6, height=4)

##### Fourth video CC123 ####

#Goal here is to figure out which genera are significant for SCN, moving beyond Wilcox test

#Load in data from previous steps so you don't need to run it every time

#Uncomment these lines if you dont want to run the source data file
#composite <- read_tsv("processed_data/composite.tsv")
#sig_genera <-read_tsv("processed_data/sig_genera.tsv")

test <- composite %>% 
  inner_join(sig_genera, by='taxonomy') %>% #Only look at patient metadata for bacteria that were significantly different
  select(group, taxonomy, rel_abund, fit_result, srn) %>% #For the metadata we only want 1) SRN 2) taxonomy 3) relative abundance 4) fit result 5) group ID
  pivot_wider(names_from=taxonomy, values_from=rel_abund) %>%
  pivot_longer(cols=-c(group, srn), names_to="metric", values_to="score") %>%
  filter(metric == "fit_result") #FIT score is a good recommender for whether an individual is likely to have SRN, and used as comparison

#Build a ROC curve based on FIT score

#create function arguments
#Threshold: Defined by criteria, for example for FIT result we use 100
#Score: FIT result
#Actual: Actual SRN result (whether or not an individual has the disease)
#Direction: So if higher values are associated wth positive, then we would want greater than, if lower values were associated then we'd want less than

get_sens_spec <- function(threshold, score, actual, direction){
  
  #Testing block to show that FIT predicts SRN as it should
  #threshold <-  100
  #score <- test$score #So function pulls test dataframe
  #actual <- test$srn #So function pulls test dataframe
  #direction <- "greaterthan"
  
  predicted <- if(direction == "greaterthan") {
    score > threshold
  } else {
    score < threshold
  }
  tp <- sum(predicted & actual)
  #tp; true positive
  tn <- sum(!predicted & !actual)
  #tn; true negatives
  fp <- sum(predicted & !actual)
  #fp; false positives
  fn <- sum(!predicted & actual)
  
  specificity <- tn / (tn + fp)
  sensitivity <- tp / (tp + fn)
  
  tibble("specificity" = specificity, "sensitivity" = sensitivity)
}

#Lets make a ROC curve based on fit-score
#Test the function again.
get_sens_spec(100, test$score, test$srn, "greaterthan")

#So we now want to the senstivity function to run over multiple thresholds

get_roc_data <- function(x, direction){
  #x <- test
  #direction <- "greaterthan"
  
  thresholds <- unique(x$score) %>% sort()
  map_dfr(.x=thresholds, ~get_sens_spec(.x, x$score, x$srn, direction)) %>%
    rbind(c(specificity = 0, sensitivity = 1))
  
}

#Now we revisit it to not just include the FIT result but other results
roc_data <- composite %>% 
  inner_join(sig_genera, by='taxonomy') %>% #Only look at patient metadata for bacteria that were significantly different
  select(group, taxonomy, rel_abund, fit_result, srn) %>% #For the metadata we only want 1) SRN 2) taxonomy 3) relative abundance 4) fit result 5) group ID
  pivot_wider(names_from=taxonomy, values_from=rel_abund) %>%
  pivot_longer(cols=-c(group, srn), names_to="metric", values_to="score") %>%
  # filter(metric == "fit_result") %>% #Remove FIT result to include other markers
  nest(data2 = -metric) %>%
  mutate(direction = if_else(metric == "Lachnospiraceae_unclassified",
                             "lessthan","greaterthan")) %>% #Unlike all other bacteria, Lachnos increases in healthy individuals
  mutate(roc_data = map2(.x = data2, .y=direction, ~get_roc_data(.x, .y))) %>%
  unnest(roc_data) %>%
  select(metric, specificity, sensitivity)


roc_data %>%
  ggplot(aes(x=1-specificity, y=sensitivity, color=metric)) +
  geom_line() +
  geom_abline(slope = 1, intercept = 0, color="gray") +
  theme_classic()

ggsave("figures/roc_figure.jpeg", device ="jpeg", width=6, height=4)





