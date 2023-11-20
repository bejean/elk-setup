
# elk-setup
## Pré-requis
```
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
sudo apt install apt-transport-https
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main"  | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
```

## Installation elasticsearch
https://www.elastic.co/guide/en/elasticsearch/reference/current/deb.html
```
sudo adduser elasticsearch
sudo apt update && sudo apt install elasticsearch
```
```
sudo -i
cd /opt
git clone https://github.com/bejean/elk-setup.git
chown -R elasticsearch: elk-setup
exit
```
```
su - elasticsearch
cd /opt/elk-setup
```



https://192.168.1.33:9200/_cat/indices/.*?v
