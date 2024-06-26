### Drought timeseries bar plot function

SPEI_annual_bar <- function(data, period.box=T, title,CFmethod=""){
  ggplot(data = data, aes(x=as.numeric(as.character(Year)), y=SPEI,fill = col)) + 
    {if(period.box==T) geom_rect(xmin=Yr-Range/2, xmax=Yr+Range/2, ymin=-Inf, ymax=Inf, alpha=0.1, fill="darkgray", col="darkgray")} +
    geom_bar(stat="identity",aes(fill=col),col="gray30",size=.8) + 
    geom_hline(yintercept=-.5,linetype=2,colour="black",size=1) +
    scale_fill_manual(name="",values =c("white","black"),drop=FALSE) +
    labs(title = title, 
         x = "Date", y = "SPEI",caption=
           if(MethodCaption == "Y"){CFmethod}) +
    guides(color=guide_legend(override.aes = list(size=7))) + PlotTheme
}

############################### FORMAT DATAFRAMES  ############################################
MonthlyWB <- read.csv(paste0(TableDir,"WB-Monthly.csv")) %>% 
  left_join(WB_GCMs,by="GCM") %>% 
  mutate(CF = replace_na(CF,"Historical"),
         CF = factor(CF, levels=c("Historical",CFs)),
         Date = as.POSIXct(paste(substr(yrmon,1,4),substr(yrmon,5,6),"1",sep="-"),format="%Y-%m-%d"),
         Year = format(Date, "%Y")) %>% 
  arrange(Date)
  


M1 <- list()
for (i in 1:length(CFs)){
  M = MonthlyWB %>% filter(CF %in% c("Historical",CFs[i])) %>% 
    complete(Date = seq(min(Date), max(Date), by = "1 month"), 
             fill = list(value = NA)) 
  
  tp<-ts(M$sum_p.mm,frequency=12,start=c(SPEI_start,1)); tp[is.na(tp)]<-0
  tpet<-ts(M$sum_pet.mm,frequency=12,start=c(SPEI_start,1)); tpet[is.na(tpet)]<-0
  SPEI<-spei(tp-tpet,SPEI_per,ref.start=c(SPEI_start,1),ref.end=c(SPEI_end,12))
  M$SPEI = SPEI$fitted[1:length(SPEI$fitted)]
  M1[[i]]<-M %>% drop_na()
}
all2<- ldply(M1, data.frame) #convert back to df
all2$SPEI[which(is.infinite(all2$SPEI))]<- -5 #getting some -Inf values that are large jumps, temp fix

# 
# all3<-subset(all2,Month==9) #Because we aggregated drought years as only applying to growing season
#                             # If you are doing for place where winter drought would be important, use following line
all3<-aggregate(cbind(sum_pet.mm,SPEI)~Year+CF,all2,mean)

###################################### PLOT ANNUAL TIME-SERIES #################################################

# MACA prep dataframe
all3$col[all3$SPEI>=0]<-"above average"
all3$col[all3$SPEI<0]<-"below average"
all3$col<-factor(all3$col, levels=c("above average","below average"))
all3$Year<-as.numeric(all3$Year)

# CF 
CF1<-subset(all3, CF %in% c("Historical",CFs[1]) )

SPEI_annual_bar(subset(CF1,Year>=Yr-Range/2 & Year<=Yr+Range/2), period.box=T,
                title=paste(SiteID, "-SPEI values for", CFs[1], "climate future", sep = " " ),CFmethod="I") 
ggsave("SPEI-CF1-Annual-bar.png", path = FigDir, width = PlotWidth, height = PlotHeight)

SPEI_annual_bar(CF1, period.box=T,
                title=paste(SiteID, "-SPEI values for", CFs[1], "climate future", sep = " " ),CFmethod="I") 
ggsave("SPEI-CF1-gridmet-Annual-bar.png", path = FigDir, width = PlotWidth, height = PlotHeight)

# CF 2
CF2<-subset(all3, CF %in% c("Historical",CFs[2]) )

SPEI_annual_bar(subset(CF2,Year>=Yr-Range/2 & Year<=Yr+Range/2), period.box=T,
                title=paste(SiteID, "-SPEI values for", CFs[2], "climate future", sep = " " ),CFmethod="I") 
ggsave("SPEI-CF2-Annual-bar.png", path = FigDir, width = PlotWidth, height = PlotHeight)

SPEI_annual_bar(CF2, period.box=T,
                title=paste(SiteID, "-SPEI values for", CFs[2], "climate future", sep = " " ),CFmethod="I") 
ggsave("SPEI-CF2-gridmet-Annual-bar.png", path = FigDir, width = PlotWidth, height = PlotHeight)


# Split into periods
drt3<-subset(all3, Year <=2012)
min(drt3$SPEI)

Future.drt<-subset(all3, Year >= Yr-Range/2 & Year <= Yr+Range/2)
min(Future.drt$SPEI)

# Calculate drought characteristics
drt3$Drought=0
drt3$Drought[which(drt3$SPEI < truncation)] <- 1

# Drought Duration calculation
# 1 Create var for beginnign drought and var for end drought, then count months between
head(drt3)

# Create count of years within CF
length(drt3$Year)
drt3$count<-seq(1, length(drt3$Year),1) 

drt3$length<-0
drt3$length <- drt3$Drought * unlist(lapply(rle(drt3$Drought)$lengths, seq_len))
mean(drt3$length[drt3$length>0])

# To get duration, now just remove those that are not droughts and do calculations on length

# Give each drought period an ID
D<-which(drt3$length==1)
HistoricalDrought<-data.frame()
HistoricalDrought<-setNames(data.frame(matrix(ncol=9,nrow=length(D))),c("DID","Start","End","Year","per","CF","duration","severity","peak"))
HistoricalDrought$Start = Sys.time(); HistoricalDrought$End = Sys.time()
HistoricalDrought$per<-as.factor("H")


# Calculate variables for each drought period
for (i in 1:length(D)){
  HistoricalDrought$DID[i]<-i
  HistoricalDrought$Start[i]<-as.Date(paste0(drt3$Year[D[i]],"-01-01"),format="%Y-%m-%d")
  HistoricalDrought$Year[i]<-drt3$Year[D[i]]
}

ND<- which((drt3$length == 0) * unlist(lapply(rle(drt3$length)$lengths, seq_len)) == 1)
if(ND[1]==1) ND<-ND[2:length(ND)]
if(drt3$Drought[length(drt3$Drought)]==1) ND[length(ND)+1]<-length(drt3$length)

###### !!!!!!!!!!! 
# If last row in drought df is a drought period - use next line of code. Otherwies proceed.
# ND[length(ND)+1]<-length(drt3$length) #had to add this step because last drought went until end of df so no end in ND

#Duration # months SPEI < truncation; Severity # Sum(SPEI) when SPEI < truncation; Peak # min(SPEI) when SPEI < truncation

for (i in 1:length(ND)){
  HistoricalDrought$End[i]<-as.Date(paste0(drt3$Year[ND[i]],"-01-01"),format="%Y-%m-%d")
  HistoricalDrought$duration[i]<-drt3$length[ND[i]-1]
  HistoricalDrought$severity[i]<-sum(drt3$SPEI[D[i]:(ND[i]-1)])
  HistoricalDrought$peak[i]<-min(drt3$SPEI[D[i]:(ND[i]-1)])
}

## Freq
d<-which(drt3$length==1)
nd<-which((drt3$length == 0) * unlist(lapply(rle(drt3$length)$lengths, seq_len)) == 1)
if(length(nd)>length(d)) {nd=nd[2:length(nd)]}
for (j in 1:length(d)){
  HistoricalDrought$freq[which(HistoricalDrought$Year==drt3$Year[d[j]])] <-
    drt3$count[d[j+1]]-drt3$count[nd[j]]
}

####### Future
# Calculate drought characteristics
Future.drt$Drought=0
Future.drt$Drought[which(Future.drt$SPEI < truncation)] <- 1

# Drought Duration calculation
# 1 Create var for beginnign drought and var for end drought, then count months between
head(Future.drt)

# Create count of months within CF
length(Future.drt$CF)/length(unique(Future.drt$CF))


# Give each drought period an ID
FutureDrought<-data.frame()
FutureDrought<-setNames(data.frame(matrix(ncol=10,nrow=0)),c("DID","Start","End","Year","per","CF","duration","severity","peak","freq"))
FutureDrought.i <- FutureDrought #Create empty CF to be used later

Future.drt$CF <- droplevels(Future.drt$CF)
CF.split<-split(Future.drt,Future.drt$CF) #split so can run on each CF df individually

# Calculate drought characteristics for each CF -- have to split by CF to avoid mixing up counts
for (c in 1:length(CF.split)){
  name=as.character(unique(CF.split[[c]]$CF))
  
  
  CF.split[[c]]$count<-rep(seq(1, length(CF.split[[c]]$CF)/length(unique(CF.split[[c]]$CF)), 
                               1),length(unique(CF.split[[c]]$CF))) # repeat # of CFs - doesn't actually need to be done now that split dfs -- just seq
  
  CF.split[[c]]$length<-0 
  CF.split[[c]]$length <- CF.split[[c]]$Drought * unlist(lapply(rle(CF.split[[c]]$Drought)$lengths, seq_len)) #Create sequence of each drought event, between each 1st Drought==1 and Drought==0
  mean(CF.split[[c]]$length[CF.split[[c]]$length>0]) #Avg length of drought event
 
  # To get duration, now just remove those that are not droughts and do calculations on length
  
  # Give each drought period an ID
  
  D<-which(CF.split[[c]]$length==1) #D is df with row that is start of each drought period
  fd <- FutureDrought.i #pull back up empty df
  if(length(D)>0) { #If there are any future droughts
    fd[length(D),] <- NA #create an empty row to hold each drought event, set all values to NA
  } else {
    fd[1,] <- 0 #otherwise set all values to 0
  }
  
  fd$per<-as.factor("F") #set period
  fd$CF = name #set CF 
  
  for (i in 1:length(D)){
    fd$DID[i]<-i #Create ID for each drought event
    fd$Start[i]<-as.character(as.Date(paste0(CF.split[[c]]$Year[D[i]],"-01-01"),format="%Y-%m-%d")) #Date as start yaer
    fd$Year[i]<-CF.split[[c]]$Year[D[i]] #start year
  }
  
  ND<- which((CF.split[[c]]$length == 0) * unlist(lapply(rle(CF.split[[c]]$length)$lengths, seq_len)) == 1) #Index of 1st period of non drought for non-drought runs
  if(length(ND)==0) { print("all drought")} else{ #If no periods without drought
    if(ND[1]==1 & length(D)>0) {ND<-ND[2:length(ND)]} #if non-drought starts on 1st year and there is a drought
  }
  if(CF.split[[c]]$Drought[length(CF.split[[c]]$Drought)]==1) ND[length(ND)+1]<-length(CF.split[[c]]$length) # If final year is drought, adds another value that is the final year
  
  for (i in 1:length(ND)){
    fd$End[i]<- if(is.na(fd$End[i])) {
      as.character(as.Date(paste0(max(CF.split[[c]]$Year),"-01-01"),format="%Y-%m-%d"))
      } else {as.character(as.Date(paste0(CF.split[[c]]$Year[ND[i]],"-01-01"),format="%Y-%m-%d")) }
    if(length(D) > 0){
      fd$severity[i]<-sum(CF.split[[c]]$SPEI[D[i]:(ND[i]-1)]) # This is where breaking - lengh(ND)=1 so get NA
      fd$peak[i]<-min(CF.split[[c]]$SPEI[D[i]:(ND[i]-1)])
      fd$duration[i]<-CF.split[[c]]$length[ND[i]-1]
    } else {
      fd$severity[i]<-0
      fd$peak[i]<-0
      fd$duration[i]<-0
    }
  }
  
  ## Freq
  d<-which(CF.split[[c]]$length==1)
  nd<-which((CF.split[[c]]$length == 0) * unlist(lapply(rle(CF.split[[c]]$length)$lengths, seq_len)) == 1)
  if(length(nd)>length(d)) {nd=nd[2:length(nd)]}
  for (j in 1:length(d)){
    fd$freq[which(fd$Year==CF.split[[c]]$Year[d[j]])] <-
      CF.split[[c]]$count[d[j+1]]-CF.split[[c]]$count[nd[j]]
  }
  FutureDrought <- rbind(FutureDrought,fd)
  rm(fd)
}
rm(FutureDrought.i)
FutureDrought$CF = factor(FutureDrought$CF, levels = FutureSubset)
Future.drt <- ldply(CF.split, data.frame) #convert back to df

########### Merge
head(HistoricalDrought)
head(FutureDrought)
Drought<-rbind(HistoricalDrought,FutureDrought)
write.csv(Drought,paste0(TableDir,"Drt.all.csv"),row.names=FALSE)  # csv with all drought events

Hist_char<-setNames(data.frame(matrix(ncol=6,nrow=1)),c("CF","per","Duration","Severity","Intensity","Frequency"))
Hist_char$CF<-"Historical"
Hist_char$per<-"H"
Hist_char$Frequency<-mean(HistoricalDrought$freq,na.rm=TRUE)
Hist_char$Duration<-mean(HistoricalDrought$duration)
Hist_char$Severity<-mean(HistoricalDrought$severity)
Hist_char$Intensity<-mean(HistoricalDrought$peak)
Hist_char$Drt.Free <- mean(rle(drt3$length)$lengths[which(rle(drt3$length)$values==0)])


Drought_char<-setNames(data.frame(matrix(ncol=6,nrow=length(levels(FutureDrought$CF)))),c("CF","per","Duration","Severity","Intensity","Frequency"))
Drought_char$CF<-levels(FutureDrought$CF)
Drought_char$per<-"F"
for (i in 1:length(Drought_char$CF)){
  name<-Drought_char$CF[i]
  Drought_char$Frequency[i]<-mean(FutureDrought$freq[which(FutureDrought$CF == name)],na.rm=TRUE)
  Drought_char$Duration[i]<-mean(FutureDrought$duration[which(FutureDrought$CF == name)])
  Drought_char$Severity[i]<-mean(FutureDrought$severity[which(FutureDrought$CF == name)])
  Drought_char$Intensity[i]<-mean(FutureDrought$peak[which(FutureDrought$CF == name)])
  Drought_char$Drt.Free[i]<-mean(rle(subset(Future.drt,CF==name)$length)$lengths[which(rle(subset(Future.drt,CF==name)$length)$values==0)])
}

Drought_char<-rbind(Hist_char,Drought_char) 
Drought_char$Severity = Drought_char$Severity*-1
Drought_char$Intensity = Drought_char$Intensity*-1
Drought_char$Frequency[is.na(Drought_char$Frequency)] <- 0
Drought_char$Severity[is.na(Drought_char$Severity)] <- 0
Drought_char$Drt.Free[is.na(Drought_char$Drt.Free)] <- 0

# csv for averages for each CF for hist and future periods
write.csv(Drought_char,paste0(TableDir,"Drought_characteristics.csv"),row.names=FALSE)


########################################### BAR PLOTS ###############################################
#Drought duration barplot
Drought_all = Drought_char
Drought_all$CF = factor(Drought_all$CF, levels = c("Historical",CFs))

#Drought duration barplot
var_bar_plot(Drought_all,"Duration", colors3, paste0(SiteID, "-Average Drought Duration"), "Years",CFmethod="I")
ggsave("DroughtDuration-Bar.png", path = FigDir, height=PlotHeight, width=PlotWidth)

#Drought severity barplot
var_bar_plot(Drought_all,"Severity", colors3, paste0(SiteID, "-Average Drought Severity"), 
             "Severity (Intensity * Duration)",CFmethod="I") + coord_cartesian(ylim = c(0, max(Drought_all$Severity)))
ggsave("DroughtSeverity-Bar.png", path = FigDir, height=PlotHeight, width=PlotWidth)

#Drought intensity barplot
var_bar_plot(Drought_all,"Intensity", colors3, paste0(SiteID, "-Average Drought Intensity"), 
             "Intensity (Minimum SPEI values)",CFmethod="I") + coord_cartesian(ylim = c(0, max(Drought_all$Intensity)))
ggsave("DroughtIntensity-Bar.png", path = FigDir, height=PlotHeight, width=PlotWidth)

#Drought-free interval barplot
var_bar_plot(Drought_all,"Drt.Free", colors3, paste0(SiteID, "-Average Drought-Free Interval"), 
             "Years",CFmethod="I")
ggsave("DroughtFrequency-Bar.png", path = FigDir, height=PlotHeight, width=PlotWidth)


####################################### REPORT FIGURES ##############################################
# Option 1
a <- SPEI_annual_bar(CF1, period.box=T,
                title=CFs[1]) + coord_cartesian(ylim = c(min(all3$SPEI), max(all3$SPEI)))
b <- SPEI_annual_bar(CF2, period.box=T,
                     title=CFs[2]) +  coord_cartesian(ylim = c(min(all3$SPEI), max(all3$SPEI)))

c <- var_bar_plot(Drought_all,"Duration", colors3, "Duration", "Years")
d <- var_bar_plot(Drought_all,"Drt.Free", colors3, "Drought-free\ninterval", 
             "Years")
e<- var_bar_plot(Drought_all,"Severity", colors3, "Severity", 
                  "Severity \n(Intensity * Duration)")+ coord_cartesian(ylim = c(0, max(Drought_all$Severity)))

spei.time <- grid_arrange_shared_legend(a + rremove("ylab") + rremove("x.text"),b +  rremove("ylab"),
                                        nrow=2,ncol=1,position="bottom")

spei.time <- annotate_figure(spei.time, left = textGrob("SPEI", rot = 90, vjust = 1, gp = gpar(cex = 2)))

drt.char <- grid.arrange(c+rremove("x.text"),d+rremove("x.text"),e,nrow=3,
                         top = textGrob(paste0(SiteID, "-Average drought \ncharacteristics"),gp=gpar(fontface="bold", col="black", fontsize=20,hjust=0.5)))

g <- grid.arrange(spei.time, drt.char,ncol = 2, clip = FALSE)
annotate_figure(g,fig.lab=if(MethodCaption == "Y"){"I"},fig.lab.pos = "bottom.right")
ggsave("DroughtCharacteristics-1-Panel.png",path = FigDir, height=PanelHeight, width=PanelWidth,bg = 'white')


# Option 2
c <- c+ theme(legend.title=element_text(size=24),legend.text=element_text(size=22),legend.position = "bottom")
d <- d+ theme(legend.title=element_text(size=24),legend.text=element_text(size=22),legend.position = "bottom")
e <- e+ theme(legend.title=element_text(size=24),legend.text=element_text(size=22),legend.position = "bottom")

drt.char <-grid_arrange_shared_legend(c+ rremove("x.text"),d+ rremove("x.text"),e+ rremove("x.text"),
                                      ncol=3,nrow=1,position="bottom",
                                      top = textGrob(paste0(SiteID, "-Average drought characteristics"),gp=gpar(fontface="bold", col="black", fontsize=26,hjust=0.5)))
g <- grid.arrange(spei.time, drt.char,nrow=2,ncol = 1, clip = FALSE)
annotate_figure(g,fig.lab=if(MethodCaption == "Y"){"I"},fig.lab.pos = "bottom.right")
ggsave("DroughtCharacteristics-2-Panel.png",path = FigDir, height=PanelHeight, width=PanelWidth,bg = 'white') 

# Only SPEI plots
g <- grid.arrange(spei.time,nrow=1,ncol = 1, clip = FALSE)
annotate_figure(g,fig.lab=if(MethodCaption == "Y"){"I"},fig.lab.pos = "bottom.right")
ggsave("SPEI-panel.png",path = FigDir, height=PanelHeight/2, width=PanelWidth,bg = 'white')

#Only characteristics plots
drt.char <-grid_arrange_shared_legend(c+ rremove("x.text"),d+ rremove("x.text"),e+ rremove("x.text"),
                                      ncol=3,nrow=1,position="bottom",
                                      top = textGrob(paste0(SiteID, "-Average drought characteristics"),gp=gpar(fontface="bold", col="black", fontsize=26,hjust=0.5)))
annotate_figure(drt.char,fig.lab=if(MethodCaption == "Y"){"I"},fig.lab.pos = "bottom.right")
ggsave("Drought-characteristics-panel.png",path = FigDir, height=PanelHeight/2, width=PanelWidth,bg = 'white')
