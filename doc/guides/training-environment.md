## Govuk Training Environment Documentation

Main site:
https://www.training.govuk.digital/

Whitehall signon :
https://signon.training.govuk.digital/

Whitehall dashboard:
https://whitehall-admin.training.govuk.digital/government/admin/

Training Jenkins:
https://deploy.training.govuk.digital/

Training Icinga:
https://alert.training.govuk.digital


### Notes on Training Load Balancers

The external load balancers are not actually being used in any environment. Only the public and internal load balancers are in use. The external load balancers are part of an older project which has now been abandoned. As part of the refactoring done while the Training environment was being built, a variable was added to the app projects to optionally include an external load balancer. In the training environment this is always set to false.

### The Datasync
You can find documentation on the datasync here:
https://docs.publishing.service.gov.uk/manual/govuk-env-sync.html

### Notes on the Whitehall Publisher

If the datasync has just been run some settings might need to be changed on the [Whitehall Publisher dashboard](https://whitehall-admin.training.govuk.digital/government/admin/) (you will need to have the superadmin role to do this). Click on the "Apps" meunu item at the top of the dashboard, this will take you to a page that lists all the available services, scroll down to "Whitehall" and click the link. You will be taken to a page with redirection URLs.

Delete the word "internal" from any of these URLs. For example change:

https://whitehall-admin.training.govuk-internal.digital/

to:

https://whitehall-admin.training.govuk.digital/

Save your changes and you should now be able to access the Whitehall publisher.
