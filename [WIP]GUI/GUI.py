# -*- coding: utf-8 -*-
from __future__ import print_function, division, unicode_literals

import sys
import os
import re
import serial.tools.list_ports  # Pour lister les ports série
from PySide6.QtWidgets import (QApplication, QMainWindow, QFileDialog, QPushButton,
                             QTextEdit, QLineEdit, QLabel, QCheckBox, QVBoxLayout, QWidget, QSizePolicy, QSpacerItem, QGroupBox, QProgressBar, QMessageBox)
from PySide6.QtCore import QProcess, Qt
from PySide6.QtGui import QPixmap  # Importer QPixmap

# Constantes de configuration
WINDOW_TITLE = u"Acompilator IDE"
WINDOW_GEOMETRY = (100, 100, 600, 600)  # Réduire la hauteur de la fenêtre
GUI_VERSION = u"1.0"

class AcompilatorGUI(QMainWindow):
    def __init__(self):
        super(AcompilatorGUI, self).__init__()
        self.setWindowTitle(WINDOW_TITLE)
        self.setGeometry(*WINDOW_GEOMETRY)

        self.setup_ui()
        self.setup_process()
        self.detect_arduinos()

    def setup_ui(self):
        """Configuration des éléments de l'interface utilisateur"""
        
        # Conteneur principal
        central_widget = QWidget(self)
        self.setCentralWidget(central_widget)

        # Mise en place du layout vertical
        layout = QVBoxLayout(central_widget)
        layout.setAlignment(Qt.AlignCenter)

        # Ajout du logo principal avec mise à l'échelle
        self.logo_pixmap = QPixmap("C:/Users/Administrateur/Downloads/Logo 3W.png")  # Chemin vers le logo principal
        self.logo_pixmap = self.logo_pixmap.scaled(300, 100, Qt.KeepAspectRatio)  # Redimensionner le logo
        self.logo_label = QLabel(self)
        self.logo_label.setPixmap(self.logo_pixmap)
        self.logo_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.logo_label, alignment=Qt.AlignCenter)

        # Label pour le chemin du compilateur
        self.compiler_label = QLabel(u"Selectionnez le fichier du compilateur :", self)
        layout.addWidget(self.compiler_label)

        # Champ pour le chemin du compilateur
        self.compiler_path = QLineEdit(self)
        self.compiler_path.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)  # S'étendre horizontalement
        layout.addWidget(self.compiler_path)

        # Bouton pour parcourir et sélectionner le compilateur
        self.compiler_browse_button = QPushButton(u"Parcourir", self)
        self.compiler_browse_button.clicked.connect(self.select_compiler)
        layout.addWidget(self.compiler_browse_button)

        # Label pour le dossier de travail
        self.folder_label = QLabel(u"Selectionnez le dossier de travail :", self)
        layout.addWidget(self.folder_label)

        # Champ pour le chemin du dossier de travail
        self.folder_path = QLineEdit(self)
        self.folder_path.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)  # S'étendre horizontalement
        layout.addWidget(self.folder_path)

        # Bouton pour parcourir et sélectionner le dossier
        self.folder_browse_button = QPushButton(u"Parcourir", self)
        self.folder_browse_button.clicked.connect(self.select_folder)
        layout.addWidget(self.folder_browse_button)

        # Groupe de cases à cocher pour les options de compilation
        self.options_group = QGroupBox(u"Options de compilation", self)
        layout.addWidget(self.options_group)

        # Layout pour les options de compilation
        options_layout = QVBoxLayout(self.options_group)

        # Case à cocher pour l 'option -y
        self.y_option = QCheckBox(u"-y", self)
        options_layout.addWidget(self.y_option)

        # Case à cocher pour l'option -n
        self.n_option = QCheckBox(u"-n", self)
        options_layout.addWidget(self.n_option)

        # Case à cocher pour l'option - nocleanup
        self.nocleanup_option = QCheckBox(u"-nocleanup", self)
        options_layout.addWidget(self.nocleanup_option)

        # Case à cocher pour l'option de test du compilateur
        self.test_compiler_option = QCheckBox(u"Test du compilateur", self)
        options_layout.addWidget(self.test_compiler_option)

        # Groupe de cases à cocher pour les cartes Arduino
        self.board_group = QGroupBox(u"Cartes Arduino", self)
        layout.addWidget(self.board_group)

        # Layout pour les cartes Arduino
        board_layout = QVBoxLayout(self.board_group)

        # Liste des cartes Arduino détectées
        self.board_checkboxes = []

        # Bouton pour lancer la compilation
        self.compile_button = QPushButton(u"Lancer la compilation", self)
        self.compile_button.clicked.connect(self.compile)
        layout.addWidget(self.compile_button)

        # Barre de progression pour la compilation
        self.progress_bar = QProgressBar(self)
        self.progress_bar.setValue(0)  # Réinitialiser la barre de progression
        layout.addWidget(self.progress_bar)

        # Zone de texte pour les messages de sortie
        self.output_text = QTextEdit(self)
        self.output_text.setReadOnly(True)  # Rendre la zone de texte en lecture seule
        layout.addWidget(self.output_text)

        # Espacement vertical pour séparer les éléments
        spacer = QSpacerItem(20, 40, QSizePolicy.Minimum, QSizePolicy.Expanding)
        layout.addItem(spacer)

    def setup_process(self):
        """Configuration du processus de compilation"""
        
        self.process = QProcess(self)
        self.process.readyReadStandardOutput.connect(self.on_ready_read_standard_output)
        self.process.readyReadStandardError.connect(self.on_ready_read_standard_error)
        self.process.started.connect(self.on_started)
        self.process.finished.connect(self.on_finished)

    def detect_arduinos(self):
        """Détection des cartes Arduino"""
        
        # Liste des ports série disponibles
        ports = serial.tools.list_ports.comports()

        # Ajout des cartes Arduino détectées
        for port in ports:
            checkbox = QCheckBox(port.description, self)
            self.board_checkboxes.append(checkbox)
            self.board_group.layout().addWidget(checkbox)

    def select_compiler(self):
        """Sélection du compilateur"""
        
        compiler_path, _ = QFileDialog.getOpenFileName(
            self, 
            u"Sélectionnez le fichier du compilateur", 
            os.getcwd(), 
            u"Tous les fichiers (*)"
        )
        self.compiler_path.setText(compiler_path)

    def select_folder(self):
        """Sélection du dossier de travail"""
        
        folder_path = QFileDialog.getExistingDirectory(self, u"Sélectionnez le dossier de travail", os.getcwd())
        self.folder_path.setText(folder_path)

    def compile(self):
        """Lancer la compilation"""
        
        compiler_path = self.compiler_path.text()
        folder_path = self.folder_path.text()
        y_option = self.y_option.isChecked()
        n_option = self.n_option.isChecked()
        nocleanup_option = self.nocleanup_option.isChecked()
        test_compiler_option = self.test_compiler_option.isChecked()

        # Vérifier que les champs sont valides
        if not compiler_path or not os.path.exists(compiler_path):
            QMessageBox.critical(self, u"Erreur", u"Le chemin du compilateur est invalide.")
            return

        if not folder_path or not os.path.exists(folder_path):
            QMessageBox.critical(self, u"Erreur", u"Le dossier de travail est invalide.")
            return

        # Compiler le code
        command = [compiler_path]
        if y_option:
            command.append(u"-y")
        if n_option:
            command.append(u"-n")
        if nocleanup_option:
            command.append(u"-nocleanup")
        command.append(u"-p=" + folder_path)  # Assurez-vous que le chemin est bien formaté

        if not test_compiler_option:
            selected_boards = [checkbox.text() for checkbox in self.board_checkboxes if checkbox.isChecked()]
            if not selected_boards:
                QMessageBox.critical(self, u"Erreur", u"Aucune carte Arduino sélectionnée.")
                return
            for board in selected_boards:
                command.append(u"--board=" + board)

        # Afficher la commande pour le débogage
        print("Commande à exécuter : ", " ".join(command))

        try:
            self.process.setProgram(command[0])
            self.process.setArguments(command[1:])
            self.process .start()
            self.progress_bar.setValue(0)  # Réinitialiser la barre de progression
        except Exception as e:
            self.output_text.append(u" Erreur lors du démarrage du processus de compilation : " + str(e))

    def strip_ansi_escape_sequences(self, text):
        """Supprime les séquences d'échappement ANSI d'une chaîne de caractères."""
        ansi_escape = re.compile(r'\x1B\[[0-?9;]*[mK]')
        return ansi_escape.sub('', text)

    def on_ready_read_standard_output(self):
        """Lecture de la sortie standard"""
        
        output = self.process.readAllStandardOutput().data().decode('utf-8')
        cleaned_output = self.strip_ansi_escape_sequences(output)
        self.output_text.append(cleaned_output)

    def on_ready_read_standard_error(self):
        """Lecture de la sortie d'erreur"""
        
        error = self.process.readAllStandardError().data().decode('utf-8')
        cleaned_error = self.strip_ansi_escape_sequences(error)
        self.output_text.append(cleaned_error)

    def on_started(self):
        """Démarrage du processus de compilation"""
        self.compile_button.setEnabled(False)  # Désactiver le bouton de compilation
        self.output_text.clear() # Effacer la zone de texte

    def on_finished(self):
        """Fin du processus de compilation"""
        
        self.compile_button.setEnabled(True)  # Réactiver le bouton de compilation

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = AcompilatorGUI()
    window.show()
    sys.exit(app.exec_())
