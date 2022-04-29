# frozen_string_literal: true

Rails.application.routes.draw do
  get '/', to: 'pages#index'
  get '/authenticated', to: 'pages#authenticated'
  get '/logged_in', to: 'pages#logged_in'
  get '/request_count', to: 'pages#request_count'
end
