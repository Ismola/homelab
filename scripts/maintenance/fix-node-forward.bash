# A veces, despues de actualizar esto se puede romper. Se suele ver porque los pods de ciertos nodos no pueden contactar con IPs de tailscale, como la BBDD

iptables-nft -C FORWARD \
  -s 10.42.0.0/16 \
  -d 10.42.0.0/16 \
  -j ACCEPT 2>/dev/null ||
iptables-nft -I FORWARD 1 \
  -s 10.42.0.0/16 \
  -d 10.42.0.0/16 \
  -m comment \
  --comment "allow-k3s-pod-forwarding" \
  -j ACCEPT