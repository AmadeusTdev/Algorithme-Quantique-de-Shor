namespace ShorAlgorithm {
    open Microsoft.Quantum.Measurement;
    open Std.Convert; // Permet d'importer IntAsDouble !
    open Std.Math;    // Contient PI() et les fonctions mathématiques
    open Microsoft.Quantum.Math;

    // FAIT PAR IA:
    operation AppliquerQFT(registreControle : Qubit[]) : Unit is Adj {
        let n = Length(registreControle);

        for i in 0 .. n - 1 {
            // 1. Appliquer la porte Hadamard
            H(registreControle[i]);
        
            // 2. Appliquer les rotations de phase contrôlées
            for j in i + 1 .. n - 1 {

                // 1 <<< (j - i + 1) calcule exactement 2^(j - i + 1) sous forme d'entier (décalage de bit)
                let puissanceDeuxEntière = 1 <<< (j - i + 1);
                let angle = (2.0 * PI()) / IntAsDouble(puissanceDeuxEntière);

                // Phase contrôlée par le qubit j sur le qubit i
                Controlled R1([registreControle[j]], (angle, registreControle[i])); // Applique R1() seulement si le qubit j est à 1
            }
        }
    
        // 3. Inverser l'ordre des qubits (SWAP) pour finaliser la QFT
        for i in 0 .. (n / 2) - 1 {
            SWAP(registreControle[i], registreControle[n - 1 - i]);
        }
    }

    // FAIT PAR IA:
    operation AjouterConstanteQFT(constante : Int, registre : Qubit[]) : Unit is Adj + Ctl {
        let n = Length(registre);
    
        // On parcourt chaque qubit du registre
        for i in 0 .. n - 1 {
            // Pour chaque qubit, on regarde l'impact des bits de la constante
            for j in 0 .. i {
                // Extraction du bit pertinent de la constante par décalage et masque
                // (constante >>> (i - j)) % 2 détermine si le bit vaut 1 ou 0
                if (((constante >>> (i - j)) &&& 1) == 1) {
                    // Calcul de l'angle de phase de Draper : π / 2^j
                    // On utilise le décalage de bit (1 <<< j) pour simuler 2^j
                    let angle = PI() / IntAsDouble(1 <<< j);
                
                    // On applique la rotation de phase
                    R1(angle, registre[i]);
                }
            }
        }
    }

    operation AppliquerAdditionModulaire(fractionC : Int, N : Int, qubitControle1 : Qubit, qubitControle2 : Qubit, registreCible : Qubit[], qubitRetenue : Qubit) : Unit is Adj {
        //------------------ Première addition ------------------
        // On fait l'addition de la constante fractionC
        Controlled AjouterConstanteQFT([qubitControle1, qubitControle2], (fractionC, registreCible));
            
        // On ajoute ensuite -N (non contrôlé) pour voir si on a débordé ou pas, on ajoutera ensuite N conditionnellement si on a débordé
        AjouterConstanteQFT(-N, registreCible);

        // On regarde si on a débordé en mesurant le qubit de retenue (le dernier qubit du registre cible)

        // --- Étape intermédiaire requise par Beauregard ---
        // On repasse temporairement hors de la QFT pour copier le bit de signe 
        // (le qubit de poids fort) dans notre qubitRetenue (carry), puis on revient dans la QFT.
        Adjoint AppliquerQFT(registreCible);
        Controlled X([registreCible[Length(registreCible)-1]], qubitRetenue);
        AppliquerQFT(registreCible);

        //------------------ Seconde addition ------------------
        // On re-ajoute N au registre cible si on a débordé (si le qubit de retenue est à 1)
        Controlled AjouterConstanteQFT([qubitRetenue], (N, registreCible));

        //------------------ Troisième addition ------------------
        // On refait une soustraction de la constante C pour réinitialiser le carry
        Controlled AjouterConstanteQFT([qubitControle1, qubitControle2], (-fractionC, registreCible));

        //------------------ Qubit de retenue désintriquer ------------------
        // --- Nettoyage final du qubit de retenue ---
        Adjoint AppliquerQFT(registreCible);
        X(qubitRetenue);
        Controlled X([registreCible[Length(registreCible)-1]], qubitRetenue);
        X(qubitRetenue);
        AppliquerQFT(registreCible);

        //------------------ On re-additionne C car on l'avait enlever pour désintriquer le qubit de retenue ------------------
        // On ré-effectue l'addition de C pour finaliser l'état quantique propre
        Controlled AjouterConstanteQFT([qubitControle1, qubitControle2], (fractionC, registreCible));
    }

    operation AppliquerMultiplicationModulaire(a : Int, N : Int, n : Int, qubitControle : Qubit, registreCible : Qubit[], i : Int, tableauC : Int[], tableauCInverse : Int[]) : Unit {

        // K * y = K * (2^0 * y0 + 2^1 * y1 + ... + 2^(n-1) * yn-1)
        // K * y = (K*2^0)*y0 + (K*2^1)*y1 + ... + (K*2^(n-1))*yn-1
        // On calcule donc la constante K = a^(2^i) mod N pour chaque qubit du registre de contrôle
        // Puis avec le qubit contrôleur yi on applique l'addition modulaire pour ajouter (K*2^i)*yi au registre cible

        //------------------ On crée un troisième registre cible temporaire sur lequel on va appliquer les additions modulaire successives ------------------
        // On ne peut pas appliquer les additions modulaire directement sur le registre cible car l'un des qubits contrôleur fait partie du registre cible, on utilise donc un registre temporaire
        // On commence avec tous les qubits à 0
        use etat3 = Qubit[n]; // Même taille que l'état 2 vu qu'il le remplacera

        //------------------ Calcule de la constante ------------------
        //let C = ((a^2.0)^i) % N; // On calcule la constante a^(2^i) mod N
        let C = tableauC[i]; // On récupère la constante pré-calculée a^(2^i) mod N

        //------------------ Qubit de retenue (pour les additions modulaire) ------------------
        use qubitRetenue = Qubit();

        // On applique une QFT inversé sur le registre cible pour pouvoir lire binairement ses qubits
        Adjoint AppliquerQFT(registreCible);

        //------------------ Additions modulaire QFT sur le registre temporaire ------------------
        // On boucle sur chaque qubit du registre cible
        for j in 0..(n-1) {
            let fractionC = (C * (1 <<< j)) % N;
            AppliquerAdditionModulaire(fractionC, N, qubitControle, registreCible[j], etat3, qubitRetenue);
        }

        // On applique une QFT sur le registre cible pour pouvoir repasser "dans" la QFT
        AppliquerQFT(registreCible);

        //------------------ On SWAP le registre intermédiaire avec le registre cible ------------------
        // Car le registre intermédiaire contient maintenant K * Y
        for j in 0..(n-1) { // On intervertit chaque qubit du registre intermediaire et du registre cible (comme ca le résultat K * Y va dans le registre cible)
            SWAP(etat3[j], registreCible[j]);
        }

        //------------------ On met maintenant le registre intermédiaire dans l'état binaire 0 ------------------
        // Le registre intermédiaire possède maintenant la valeur Y après le swap

        // On applique une QFT inversé sur le registre cible pour pouvoir lire binairement ses qubits
        Adjoint AppliquerQFT(registreCible);
        
        // On doit annuler l'état pour que etat3 revienne à |0>.
        // Puisque registreCible contient maintenant (K * Y), et etat3 contient Y,
        // on utilise l'inverse modulaire de C (noté CInverse) pour soustraire de registreCible
        // en étant contrôlé par les bits de etat3 (qui vaut Y).
        let C_inverse = tableauCInverse[i];

        for j in n-1..-1..0 {
            let fractionC_inverse = (C_inverse * (1 <<< j)) % N;
            Adjoint AppliquerAdditionModulaire(fractionC_inverse, N, qubitControle, registreCible[j], etat3, qubitRetenue);
        }

        // On applique une QFT sur le registre cible pour pouvoir repasser "dans" la QFT
        AppliquerQFT(registreCible);

        //------------------ On libère le registre 3 ------------------
        Adjoint AppliquerQFT(etat3); // On sort de la QFT pour avoir que des 0 binaire
        for j in 0..(n-1) { // On intervertit chaque qubit du registre intermediaire et du registre cible (comme ca le résultat K * Y va dans le registre cible)
            Reset(etat3[j]);
        }

        // On libère le qubit de retenue utiliser pour chaque addition modulaire
        Reset(qubitRetenue);
    }

    operation AppliquerExponentiationModulaire(a : Int, N : Int, n : Int, registreControle : Qubit[], registreCible : Qubit[], tableauC : Int[], tableauCInverse : Int[]) : Unit {
        // On initialise le registre cible à 1 car on va effectuer des multiplications successives, et 1 est l'élément neutre de la multiplication
        X(registreCible[0]);

        // On fait rentrer le registre cible dans le domaine de la QFT pour pouvoir faire les additions modulaires
        AppliquerQFT(registreCible);

        // On applique les multiplications modulaires contrôlées par les qubits du registre de contrôle
        for i in 0..Length(registreControle)-1 {
            AppliquerMultiplicationModulaire(a, N, n, registreControle[i], registreCible, i, tableauC, tableauCInverse);
        }

        // On fait sortir le registre cible dans le domaine de la QFT
        Adjoint AppliquerQFT(registreCible);
    }

    operation CalculerR(a : Int, N : Int, n : Int, tableauC : Int[], tableauCInverse : Int[]) : Int {
        //------------------ On prépare les deux registres ------------------
        // a et N sont des entiers, n est le nombre de qubits nécessaires pour représenter N
        // Premier registre
        // Pour pouvoir stocker jusqu'à N², on a besoin de 2n qubits. On ajoute un qubit supplémentaire pour garantir que la QFT fonctionne correctement.
        use etat1 = Qubit[(2*n)+1];
        // Deuxième registre
        use etat2 = Qubit[n]; // n qubits car la valeur max de a^n mod N est N-1 et n représente le nombre de qubits pour N

        //------------------ On applique les portes Hadamard sur le premier registre ------------------
        // On obtient donc un nombre k aléatoire que l'on peut écrire k = Alpha * r + Beta si on fait la division euclidienne par r
        for i in 0..(2*n) {
            H(etat1[i]);
        }

        //------------------ On applique la porte unitaire Ua sur les deux registres ------------------
        // Le deuxième registre prendra comme valeur a^k mod N, soit a^(Alpha * r + Beta) mod N = a^Beta mod N car a^r mod N = 1
        AppliquerExponentiationModulaire(a, N, n, etat1, etat2, tableauC, tableauCInverse);

        //------------------ On fait la mesure du deuxième registre ------------------
        // On va donc faire effondrer le deuxième registre qui choisira une valeur de a^Beta donc Beta
        for i in 0..(n-1) {
            M(etat2[i]); // Pas besoin de stocker le résultat car on ne s'en sert pas, on veut juste effondrer l'état du deuxième registre
        }

        //------------------ On applique la QFT sur le premier registre pour obtenir la fréquence ------------------
        // La fréquence sera sous la forme qlqchose / r, on pourra donc par la suite récupérer r
        Adjoint AppliquerQFT(etat1); // QFT- (adjoint est l'opération inverse)
        // Si on applique la QFT- c'est car l'intrication avec le deuxième registre à mis le premier registre "dans" le domaine de la QFT

        //------------------ On mesure la fréquence dans le premier registre ------------------
        mutable frequence = 0;

        for i in 0..(2*n) {
            let result = M(etat1[i]);
            if (result == One) {
                //let puissanceInverse = 2*n - i; // Pour lire les qubits dans le bon ordre pour reconstruire le nombre
                //set frequence = frequence + (2^puissanceInverse);
                set frequence = frequence + (1 <<< i); // + 2^i
            }
        }

        //------------------ On libère les qubits ------------------
        // Premier registre
        for i in 0..(2*n) {
            Reset(etat1[i]);
        }
        // Deuxième registre
        for i in 0..(n-1) {
            Reset(etat2[i]);
        }

        return frequence;
    }
}