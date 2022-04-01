INSERT INTO [customerbase].[PeopleStage].[tblRabatte]
select distinct Rabatt, Campaign, Run from
[customerbase].[PeopleStage].[tblCustomer] 
WHERE Campaign = '#CAMPAIGN#'
   AND Run = '#RUN#'