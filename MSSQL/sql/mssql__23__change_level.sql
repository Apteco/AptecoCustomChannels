USE [customerbase]

/* Declare variables */
DECLARE @rv int
DECLARE @urn int
DECLARE @level int

/* Set variables for this run */
set @urn = #URN#
set @level = #LEVEL#

/* Update the level of a customer */
exec @rv = customerbase.setLevel @urn, @level

/* Return result */
SELECT @rv AS return_value




