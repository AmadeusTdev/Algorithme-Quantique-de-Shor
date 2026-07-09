import random as rd
from qdk import qsharp  
from fractions import Fraction

qsharp.init(project_root = '.')

def extraire_periode(k, nb_qubits_total, N):
    if k == 0:
        print("Mesure égale à 0, impossible de déterminer la période.")
        return None
    # 1. Calcul de la phase mesurée
    phase = k / (2 ** nb_qubits_total)
    # 2. Utilisation des fractions continues via la classe Fraction de Python.
    # On cherche une fraction dont le dénominateur est inférieur à N.
    fraction_approchee = Fraction(phase).limit_denominator(N)
    # 3. Le dénominateur de cette fraction est notre candidat pour la période r
    r_candidat = fraction_approchee.denominator
    
    return r_candidat

def calculerR(a, N):
    # On calcule n avec n étant le nombre de bits nécessaires pour représenter N en binaire
    n = (N).bit_length()

    # On précalcule les constante dont l'algorithme a besoin pour effectuer les multiplications modulaires
    tableauC = []
    # Ici on met les inverses (modulo N)
    tableauInverseC = []

    # On calcule les constante a^(2^i) mod N pour chaque qubit du registre de contrôle
    # On initialise la première valeur : a^(2^0) mod N = a mod N
    valeur_courante = a % N
    valeur_couranteInverse = pow(a, -1, N) % N
    for i in range(2*n+1):
        tableauC.append(valeur_courante)
        tableauInverseC.append(valeur_couranteInverse)
    
        # Pour l'étape suivante, on élève juste la valeur courante au carré 
        # et on applique IMMÉDIATEMENT le modulo N pour que le nombre reste petit
        valeur_courante = (valeur_courante ** 2) % N
        valeur_couranteInverse = (valeur_couranteInverse ** 2) % N
    
    print("Debut algorithme de Shor quantique")

    # On utilise une f-string Python (le 'f' devant les guillemets)
    # Cela va générer la chaîne : "ShorAlgorithm.CalculerR(7, 15)"
    commande_qsharp = f"ShorAlgorithm.CalculerR({a}, {N}, {n}, {tableauC}, {tableauInverseC})"
    # On exécute la commande
    frequence = qsharp.eval(commande_qsharp)

    # On extrait la période r à partir de la fréquence mesurée
    r = extraire_periode(frequence, 2*n, N)

    print("Algorithme de Shor quantique utilisé, f =", frequence, ", r =", r)

    if frequence == 0:
        r = 0

    return r

def PGCD(a, b):
    while b != 0:
        a, b = b, a % b
    return abs(a)

def tester_r(a, N, r):
    if r % 2 == 1:
        # On recommence l'algorithme si r est impair
        return False
    elif (a**(r//2) + 1) % N == 0:
        # On recommence l'algorithme si a^(r/2) est congru à -1 modulo N
        return False
    else:
        # On a trouvé un facteur non trivial
        return True

def factoriser(N):
    a = rd.randint(2, N-1)

    if PGCD(a, N) != 1:
        # Le PGCD est différent de 1, donc on a trouvé un facteur non trivial
        facteur = PGCD(a, N)
        return facteur, N/facteur
    else:
        r = calculerR(a, N)
        # On va tester des multiples de r car l'algorithme quantique peut renvoyer un sous-multiple de r
        trouver = False
        if r != 0:
            for y in range(2): # on teste de r jusqu'à 3r
                if tester_r(a, N, r*(y+1)):
                    # On a trouvé un r qui marche
                    r = r*(y+1)
                    trouver = True
                    break
        # Si on a trouvé un r qui marche, on calcule le facteur non trivial
        if trouver:
            facteur = PGCD(a**(r // 2) - 1, N)

            if facteur == 1 or facteur == N:
                return factoriser(N)
            else:
                print("L'algorithme quantique à trouver le bon r =", r)
                return facteur, N/facteur
        else:
            return factoriser(N)

def main():
    N = 35 #15 #35 #143 #14351
    a, b = factoriser(N)
    print("Les facteurs de", N, "sont", a, "et", b)

main()