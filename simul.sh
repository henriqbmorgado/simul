#!/bin/bash
set -e

# função que simula passagem de tempo
time_past() {
  local temp=$(($1 + TIME_STEMP))
  for port in "${PORTS[@]}"; do
    ./freechains-host now $temp --port=$port
  done
  TIME_STEMP=$temp
}

# função que sincroniza a cadeia entre todos os nós
sync_chain() {
  local user1=$1
  send_port=${USR_PORT[$user1]}
  for recv_port in "${PORTS[@]}"; do
    if [ "$recv_port" != "$send_port" ]; then
        ./freechains --host=localhost:$send_port peer localhost:$recv_port send "#forum"
    fi
  done
}

# diretório base para simulação
BASE_DIR="$(pwd)/tmp/simul"

# nós, portas e users da simulação
NODES=(n0 n1 n2)
PORTS=(8330 8331 8332)
USERS=(pioneiro ativo troll newbie neutro)

# criar um diretório para cada nó
for n in "${NODES[@]}"; do
    mkdir -p "$BASE_DIR/$n"
done

# iniciar os host
for i in "${!NODES[@]}"; do
    ./freechains-host start "$BASE_DIR/${NODES[$i]}" --port=${PORTS[$i]} &
done
sleep 2

echo " "
# distribuir users pelos nós da rede
declare -A USR_PORT
for i in ${!USERS[@]}; do
  user="${USERS[$i]}"
  port=${PORTS[$((i % 3))]}
  USR_PORT[$user]=$port
done

# gerar as chaves pub e pvt
declare -A PUB PVT
for user in "${USERS[@]}"; do
    read pub pvt < <(./freechains --host=localhost:${USR_PORT[$user]} keys pubpvt "$user")
    PUB[$user]=$pub
    PVT[$user]=$pvt
done

echo " "
# nós entram no forum
for port in "${PORTS[@]}"; do
    ./freechains --host=localhost:$port chains join '#forum' ${PUB[pioneiro]} &
done
sleep 2

# definição da data base para todos os nós
TIME_STEMP=1751846400
for port in "${PORTS[@]}"; do
    ./freechains-host now $TIME_STEMP --port=$port
done

echo " "
# pioneiro realiza o primeiro post indicando as normas do forum
POST1=$(./freechains --host=localhost:${USR_PORT[pioneiro]} chain '#forum' post inline \
    'Olá! Este fórum é para discutir experiências com produtos e lojas.' --sign="${PVT[pioneiro]}")
sync_chain "pioneiro"

echo " "
# avança 18 dias
time_past $((3600 * 24 * 18))

echo " "
# ativo faz um post viral
POST2=$(./freechains --host=localhost:${USR_PORT[ativo]} chain '#forum' post inline \
    'Recomendo a loja X. Entrega rápida e atendimento ótimo.' --sign="${PVT[ativo]}")
sync_chain "ativo"

echo " "
# troll faz um post de spam
POST3=$(./freechains --host=localhost:${USR_PORT[troll]} chain '#forum' post inline \
  'aaaaaaassddddddddddddddddddsadddwdddddddddddddddddsadddddddddwsdiwqeeeeeeeeeeeesdaddadddddddd22qqqqed' --sign="${PVT[troll]}")
sync_chain "troll"

echo " "
# newbie faz um post irrelevante para o tema do forum
POST4=$(./freechains --host=localhost:${USR_PORT[newbie]} chain '#forum' post inline \
    'Gosto do bairro onde a loja K fica, adoro ir jogar bola, passear e ir ao cinama por la.' --sign="${PVT[newbie]}")
sync_chain "newbie"

echo " "
# neutro faz um post
POST5=$(./freechains --host=localhost:${USR_PORT[neutro]} chain '#forum' post inline \
  'Loja Y frequentemente tem atrasos na entrega e as embalagem não de boa qualidade.' --sign="${PVT[neutro]}")
sync_chain "neutro"

echo " "
# avança mais 22 dias
time_past $((3600 * 24 * 22))

echo " "
# reações (likes/dislikes) do pioneiro
./freechains --host=localhost:${USR_PORT[pioneiro]} chain '#forum' like "$POST2" --sign="${PVT[pioneiro]}" # pioneiro da like no post 2
./freechains --host=localhost:${USR_PORT[pioneiro]} chain '#forum' dislike "$POST3" --sign="${PVT[pioneiro]}" # pioneiro da dislike no post 3
./freechains --host=localhost:${USR_PORT[pioneiro]} chain '#forum' dislike "$POST4" --sign="${PVT[pioneiro]}" # pioneiro da like no post 4
./freechains --host=localhost:${USR_PORT[pioneiro]} chain '#forum' like "$POST5" --sign="${PVT[pioneiro]}" # pioneiro da like no post 5
sync_chain "pioneiro"

echo " "
# reações (likes/dislikes) do ativo
./freechains --host=localhost:${USR_PORT[ativo]} chain '#forum' like "$POST1" --sign="${PVT[ativo]}" # ativo da like no post 1
./freechains --host=localhost:${USR_PORT[ativo]} chain '#forum' dislike "$POST3" --sign="${PVT[ativo]}" # ativo da deslike no post 3
./freechains --host=localhost:${USR_PORT[ativo]} chain '#forum' dislike "$POST4" --sign="${PVT[ativo]}" # ativo da deslike no post 4
sync_chain "ativo"

echo " "
# reações (likes/dislikes) do neutro
./freechains --host=localhost:${USR_PORT[neutro]} chain '#forum' like "$POST2" --sign="${PVT[neutro]}" # neutro da like no post 2
sync_chain "neutro"

echo " "
# avança mais 20 dias
time_past $((3600 * 24 * 20))

echo " "
# post do newbie agora de acordo com o tema do forum
POST6=$(./freechains --host=localhost:${USR_PORT[newbie]} chain '#forum' post inline \
    'Comprei nessa loja tambem, recomendo.' --sign="${PVT[newbie]}")
sync_chain "newbie"

echo " "
# outro post viral do ativo
POST7=$(./freechains --host=localhost:${USR_PORT[ativo]} chain '#forum' post inline \
    'Loja Z está vendendo produto x com 15% de desconto, vale apena pela qualidade.' --sign="${PVT[ativo]}")
sync_chain "ativo"

echo " "
# troll faz post contendo desinformação
POST8=$(./freechains --host=localhost:${USR_PORT[troll]} chain '#forum' post inline \
  'Loja Z está vendendo produto x com 100% de desconto!!!' --sign="${PVT[troll]}")
sync_chain "troll"

echo " "
./freechains --host=localhost:${USR_PORT[ativo]} chain '#forum' like "$POST6" --sign="${PVT[ativo]}" # ativo da like no post 6
./freechains --host=localhost:${USR_PORT[ativo]} chain '#forum' dislike "$POST8" --sign="${PVT[ativo]}" # ativo da dislike no post 8
sync_chain "ativo"

echo " "
# pioneiro da like no post 7
./freechains --host=localhost:${USR_PORT[pioneiro]} chain '#forum' like "$POST7" --sign="${PVT[pioneiro]}"
sync_chain "pioneiro"

echo " "
# neutro da like no post 7
./freechains --host=localhost:${USR_PORT[neutro]} chain '#forum' like "$POST7" --sign="${PVT[neutro]}"
sync_chain "neutro"

echo " "
# newbie da like no post 7
./freechains --host=localhost:${USR_PORT[newbie]} chain '#forum' like "$POST7" --sign="${PVT[newbie]}"
sync_chain "newbie"

echo " "
# encerrar os host ao fimd asimulação
for i in "${!NODES[@]}"; do
    ./freechains-host stop --port=${PORTS[$i]}
done
sleep 2

echo " "
echo "FIM."
