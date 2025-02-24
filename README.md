
```
curl -sL https://raw.githubusercontent.com/indie-master/marzban-log-cleaner/main/marzban_log_cleanup.sh | sed 's/\r//g' | sudo tee /usr/local/bin/marzban_log_cleanup.sh > /dev/null && sudo chmod +x /usr/local/bin/marzban_log_cleanup.sh && sudo /usr/local/bin/marzban_log_cleanup.sh install
```
