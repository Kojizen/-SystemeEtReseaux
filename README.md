Projet systeme et reseaux
Problèmes a traiter :

la méthode retireCarte est la même pour les 3 fichiers elle pourrait être généralisée.

la condition dans joueur qui regarde la carte courante avec toutes les cartes du joueur fonctionne que quand la carte à jouer est la dernière carte du tableau (solution actuelle utilisée "break").

on n'utilise pas le nom et le prénom des joueurs de la partie.

on envoie les cartes jouer à tous les joueurs humains avec une fonction exécuter en tache de fond et non avec un socket.

problème de concurrence entre les joueurs quand ils veulent jouer au même moment ou au moment de distribuer les cartes (solution actuelle utilisée "sleep").

remplacer les sleep par des wait et kill qui notifie les wait: -pour obtenir le pid du dernier processus exécuté : $! -pour obtenir le pid du processus courant : $$ -pour obtenir le pid du pere du processus : $PPID Le souci étant que l'on ne peut pas récupérer le pid d'un terminale ouvert avec la commande "gnome-terminale" en tache de fond.

Note pour les sockets :

sur un terminal: nc -l -p 9091 < test

sur un autre terminal: nc localhost 9091 > test2

Ecrit dans le fichier test2 les informations contenues dans le fichier test.

sur un terminal: test=$(nc -l -p 9091)

sur un autre terminal: test2=$(echo test3 | nc localhost 9091 | echo test4)

Stock dans la variable test la chaine "test3", et dans la variable test2 la chaine "test4".
