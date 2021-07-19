# Create settings

Replace the following tokens
* `<companyId>` - The company ID of your account

Execute this script and
* enter your syniverse wallet api token (request at your account manager, if needed)
* and your sqlserver connection string to `RS_<Systemname>` database.


# Notes

* Wallet items and customers have a 1:n relationship. Please bear in mind, that the wallet_url is valid for single wallet items, so if a single person has multiple wallet items (coupons, vouchers) you should make sure to use the latest of specific wallet item per person. Bear in mind, that wallet items can also have an delete event.