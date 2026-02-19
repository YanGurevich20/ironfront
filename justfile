mod game
mod infra
mod user-service
mod matchmaker
mod fleet

[default, parallel]
fix: game::fix infra::fix user-service::fix matchmaker::fix fleet::fix

gcloud-config:
	gcloud config configurations activate ironfront