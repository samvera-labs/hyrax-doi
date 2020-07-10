Rails.application.routes.draw do
  mount Hyrax::Doi::Engine => "/hyrax-doi"
end
