# Montar carpeta NFS persistente
sudo nano /etc/fstab

# Añadir
h0:/volume1/Archivos /mnt/nas/etcd-backups nfs defaults,_netdev,nofail,x-systemd.automount 0 0

# Aplicar y comprobar
sudo mount -a
findmnt /mnt/nas/etcd-backups

# Crear script de backup
sudo nano /usr/local/bin/k3s-etcd-backup.sh

# Pegar el contenido

# Dar permisos
sudo chmod +x /usr/local/bin/k3s-etcd-backup.sh

# Ejecutar una prueba
sudo /usr/local/bin/k3s-etcd-backup.sh

# Comprobar que se ha creado el backup
ls -lh "/mnt/nas/etcd-backups/opencloud/storage/users/users/934c2b07-76cc-49eb-8738-fc4ed171f4f3/4 Archives/Backup/etcd"

# Ver el log
tail -n 50 /var/log/k3s-etcd-backup.log

# Automatizar
sudo crontab -e

# Añadir
0 3 * * * /usr/local/bin/k3s-etcd-backup.sh