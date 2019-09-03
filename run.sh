if [ $RAILS_ENV = "production" ]
then
  rake assets:precompile
  rails s -e production
else
  rake db:setup && rails s
fi
