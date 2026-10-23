class_name PartsQuote
extends RefCounted
## What an order would cost and when it would arrive. `reason` says why `ok` is false.

var ok := false
var reason := ""
var cost := 0
## Taken off by bulk discounts.
var saving := 0
var eta_day := 0
## The latest arrival, in game minutes since the company started.
var eta_minute := 0
