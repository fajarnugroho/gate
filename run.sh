if [ $RAILS_ENV = "production" ]
then
  rails s -e production
else
  rake db:setup && rails s
fi
