#!/bin/bash

noMsgAvailable=true

cartesJoueurs=()		#tableau qui represente les cartes du jeu, triees par joueur et constant le long de la manche pour pouvoir verifier les cartes posees
cartesManche=()			#tableau qui represente les cartes du jeu durant une manche
nbJoueurs=0				#nombre de joueurs
nbRobots=0				#nombre de robots
nbJoueursTotal=0		#nombre de participants total
declare -i manche=0		#nombre de manche de la partie, declare en integer (afin d'utiliser +=)
etatPartie="debut"		#etat actuel de la partie
connectPort=9091		#port sur lequel le gestionnaire ecoute
playersPort=()			#port utilise par chaque joueur pour ecouter

#lancement du serveur d'ecoute des messages
./Server.sh $connectPort 2>/dev/null &
pidServer=$!

#execute exitPartie lorsque que ctrl+c est tape
trap 'exitPartie;' INT

#initialisation des joueurs de la partie
initJoueurs()
{
	#recuperation du nombre de joueurs
	read -p 'Pour commencer, selectionner le nombre de joueur(s) : ' nbJoueurs

	if [ $nbJoueurs -ge 0 ];
	then
		if [ $nbJoueurs -gt 0 ];
		then
			for i in $(eval echo {1..$nbJoueurs});
			do
				#ouvre un terminal en tache de fond pour chaque joueur
				gnome-terminal -- bash -c "./Joueurs.sh $i; echo 'Appuyez sur entrer pour quitter'; read && exit" 1>/dev/null  & #$i represente le numero du joueur
			done
		fi
	else
		echo "Nombre de joueurs errone"
		initJoueurs
	fi
}

#initialisation des robots de la partie
initRobots()
{
	#recuperation du nombre de robots
	read -p 'Ensuite, selectionner le nombre de robot(s) : ' nbRobots

	if [ $nbRobots -ge 0 ];
	then
		if [ $nbRobots -gt 0 ];
		then
			for i in $(eval echo {1..$nbRobots});
			do
				num=$(($nbJoueurs + $i))
				#ouvre un terminal pour chaque robot mais tout est automatise
				gnome-terminal -- bash -c "./Robots.sh $num; echo 'Appuyez sur entrer pour quitter'; read && exit" 1>/dev/null & #$num represente le numero du robot
			done
		fi
	else
		echo "Nombre de robots errone"
		initRobots
	fi
}

#recuperation du premier message en attente
getNextMessage()
{
	#decompte du nombre de lignes, pour savoir si un message est disponible ou non
	nbLines=$(wc -l < tmp/socket)
	if [ $nbLines != "0" ];
	then
		noMsgAvailable=false
	fi

	#si pas de message disponible, on en attends un
	while [ $noMsgAvailable = true ];
	do
		sleep 1
		nbLines=$(wc -l < tmp/socket)
		if [ $nbLines != "0" ];
		then
			noMsgAvailable=false
		fi
	done
	
	#lecture de la premiere ligne du fichier
	local line=$(awk 'NR==1 {print; exit}' tmp/socket)

	#copie du fichier sans la premiere ligne dans un fichier temporaire, puis on transferera le contenu du fichier temporaire dans le fichier original
	awk 'NR!=1 {print;}' tmp/socket > tmp/socketTemp
	cat tmp/socketTemp > tmp/socket
	rm tmp/socketTemp

	#decompte du nombre de lignes
	nbLines=$(wc -l < tmp/socket)
	if [ $nbLines = "0" ];
	then
		noMsgAvailable=true
	fi

	#renvoie la ligne lue
	echo $line
}

#envoi le message $1 au joueur $2, via un socket
sendMessageToPlayer()
{
	msg=$1
	playerNb=$2
	echo $msg | nc -q 1 localhost ${playersPort[$playerNb]} 2>/dev/null

	#test si le message a bien ete envoye, sinon recommence
	exitCode=$?
	if [ $exitCode -ne 0 ];
	then
		sendMessageToPlayer $msg $playerNb
	fi
}

#envoi le message $1 a tous les joueurs
sendMessageToAllPlayer()
{
	msg=$1
	for j in ${!playersPort[@]};
	do
		sendMessageToPlayer $msg $j
	done
}

# melange les cartes du jeu pour la manche et les transmets aux concernes
melangeCartes()
{
	#on incremente le nombre de manche a chaque distribution de cartes au joueurs
	manche+=1

	#on verifie qu'il n'y ait pas trop de cartes a distribuer
	if [ $(($manche * $nbJoueursTotal)) -gt 100 ];
	then
		echo "Pas assez de cartes pour jouer, fin de la partie."
		exitPartie
	fi

	cartes=({1..100})			#tableau qui represente les cartes du jeu au depart

	for j in $(eval echo {1..$nbJoueursTotal});
	do
		cartesString=""
		
		#ici la manche permet de savoir combien de cartes par joueur on va distribuer
		for m in $(eval echo {1..$manche});
		do
			#indice aleatoire afin de recuperer une carte dans le jeu de cartes
			randomCarte=$(($RANDOM % $((99 - ${#cartesManche[@]}))))

			#tableau qui va stocker toutes les cartes de la manche courante
			cartesManche+=(${cartes[$randomCarte]})
			cartesJoueurs+=(${cartes[$randomCarte]})
			cartesString+="${cartes[$randomCarte]} "
			
			#carte retire pour ne pas etre choisie a nouveau
			retireCarte $randomCarte

		done

		sendMessageToPlayer "distributionCartes/${cartesString}" $j
		echo "Joueur $j a recu ses cartes"
	done
}

#retire la carte $1 du tableau des cartes.
retireCarte()
{
	carteRetiree=$1		 #indice de la carte a retirer
	cartesTemp=()		 #tableau temporaire

	#on copie les cartes dans le tableau temporaire
	cartesTemp=(${cartes[*]})

	#on vide le tableau des cartes de tout son contenu avant de le remplir
	unset cartes

	#recuperation des bonnes valeurs c'est-a-dire toutes sauf la carte retiree
	for i in ${!cartesTemp[@]};
	do
		if [ $carteRetiree -ne $i ];
		then
			cartes+=(${cartesTemp[$i]})
		fi
	done
}

#retire la carte $1 du tableau des cartes de la manche.
retireCarteManche()
{
	carteRetiree=$1		 #carte a retirer
	temp=()		 #tableau temporaire

	#on copie les cartes dans le tableau temporaire
	temp=(${cartesManche[*]})

	#on vide le tableau des cartes de tout son contenu avant de le remplir
	unset cartesManche

	#recuperation des bonnes valeurs c'est-a-dire toutes sauf la carte retiree
	for i in ${temp[*]};
	do
		if [ $carteRetiree -ne $i ];
		then
			cartesManche+=($i)
		fi
	done
}

#envoi du top depart de la manche a tous les joueurs.
topDepart()
{
	sleep $(($RANDOM % 6))
	sendMessageToAllPlayer "top"

	etatPartie="jeu"
}

#traite les informations reçues par l'ensemble des joueurs.
traitementManche()
{
	carteAJouer=100		#represente la plus petite carte de la manche en cours

	#on parcourt toutes les cartes de la manche et on cherche la plus petite carte
	for i in ${cartesManche[*]};
	do
		if [ $i -lt $carteAJouer ];
		then
			carteAJouer=$i
		fi
	done

	msg=$(getNextMessage)
	#decoupe en morceaux selon le separateur
	oldIFS=$IFS
	local IFS='/'
	read -ra msgParts <<< $msg
	IFS=$oldIFS
	if [ "${msgParts[0]}" != "poseCarte" ];
	then
		echo "Erreur, carte a jouer attendue, obtenu :" ${msgParts[0]}
	else
		carteJouee=${msgParts[1]}
		joueur=${msgParts[2]}

		#verification que le joueur possede bien cette carte et ne triche pas
		local exist=false
		for i in ${cartesManche[*]};
		do
			if [ $carteJouee -eq $i ];
			then
				exist=true
			fi
		done

		local possedee=false
		if [ $exist = true ];
		then
			for i in ${!cartesJoueurs[@]};
			do
				if [ $carteJouee -eq ${cartesJoueurs[$i]} ];
				then
					#intervalle dans lesquel est compris les cartes du joueur qui a joue (pour verifier qu'il possede bien la carte)
					debutCartesJoueur=$((($joueur - 1) * $manche))		#inclu
					finCartesJoueur=$(($debutCartesJoueur + $manche))		#exclu
					if [ $i -ge $debutCartesJoueur -a $i -lt $finCartesJoueur ];
					then
						possedee=true
					fi
				fi
			done
		fi

		if [ $possedee = true ];
		then
			echo "Carte $carteJouee jouee par le joueur $joueur"
			sendMessageToAllPlayer "cartePosee/${carteJouee}/${joueur}"

			#comparaison de la carte envoyee par le joueur avec la carte a jouer
			if [ $carteJouee -eq $carteAJouer ];
			then
				#on retire la carte des cartes de la manche
				retireCarteManche $carteJouee
				echo "Il reste ${#cartesManche[@]} cartes"

				#manche finie
				if [ ${#cartesManche[@]} -eq 0 ];
				then
					echo "Manche gagnee"
					echo
					etatPartie="mancheGagnee"
					unset cartesManche
					unset cartesJoueurs
				fi;
			else
				#la carte envoyee n'etait pas la bonne donc on arrete la partie
				echo "Mauvaise carte jouee, fin de la partie"
				sendMessageToAllPlayer "mauvaiseCarte"
				exitPartie
			fi
		else
			echo "Tentative de triche"
			sendMessageToAllPlayer "triche"
			exitPartie
		fi
	fi
}

nouvelleManche()
{
	melangeCartes
	topDepart
}

#enregistre un joueur dans la partie
enregistrementProcess()
{
	msg=$(getNextMessage)
	oldIFS=$IFS
	local IFS='/'
	read -ra msgParts <<< $msg
	IFS=$oldIFS
	if [ "${msgParts[0]}" != "register" ];
	then
		echo "Error, not register message received" ${msgParts[0]}
	else
		#on enregistre son port pour pouvoir communiquer avec lui
		playersPort[${msgParts[1]}]=${msgParts[2]}

		if [ ${#playersPort[@]} -eq $nbJoueursTotal ];
		then
			sleep 1
			nouvelleManche
		fi
	fi
}

#fait tourner la partie tant qu'elle n'est pas finie.
deroulementPartie()
{
	while [ $etatPartie != "fin" ]
	do
		case $etatPartie in

			"enregistrement")
				enregistrementProcess
				;;

			"jeu")
				traitementManche
				;;

			"mancheGagnee")
				sendMessageToAllPlayer "mancheGagnee"
				nouvelleManche
				;;
		esac

	done
}

#affiche un top 10 des parties dans le gestionnaire du jeu.
#ajoute egalement la partie terminee au fichier.
classementPartie()
{
	#saut de ligne
	echo
	#on ecrit dans le fichier Classement.txt le nombre de manche et le nombre de joueur
	#l'option -e permet d'utiliser les "\t" qui represente une tabulation
	echo -e "$manche\t\t\t$nbJoueursTotal" >> Classement.txt

	#on tri le fichier classement
	sort -n Classement.txt -o Classement.txt

	#on affiche dans le terminale du gestionnaire du jeu le top 10 avec la commande "tail"
	echo "***************************************************************************************"
	echo "Voici le classement dans l'ordre croissant des parties qui ont durees le plus longtemps"
	echo -e "Manche\t\t\tNombre de joueurs"
	tail -n 10 Classement.txt
}

#arrete la partie
exitPartie()
{
	kill -s INT $pidServer
	etatPartie="fin"

	sendMessageToAllPlayer "exitPartie"

	#comme la partie est terminee on declenche l'affichage du classement
	classementPartie
}

#demarre la partie
startPartie()
{
	etatPartie="enregistrement"
	#on initialise les joueurs de la partie
	initJoueurs
	initRobots

	nbJoueursTotal=$(($nbJoueurs + $nbRobots))
	echo "Nous avons ${nbJoueursTotal} participants pour cette partie"

	if [ $nbJoueursTotal -lt 2 ];
	then
		echo "Pas assez de joueurs pour jouer";
		startPartie
	else
		deroulementPartie
	fi
}

#fonction qui demarre la partie puis qui va appeler en cascade toutes les autres fonctions
startPartie
