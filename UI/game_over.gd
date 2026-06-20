extends CanvasLayer

# Tela de Game Over: aparece quando o jogador morre, pausa o jogo
# e permite reiniciar a fase.


func _ready():
	visible = false
	# Funciona mesmo com a árvore pausada (para o botão responder)
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Painel/Botao.pressed.connect(_on_reiniciar)

	await get_tree().process_frame
	var jogador = get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.morreu.connect(_on_jogador_morreu)
	else:
		push_error("GameOver: nenhum nó no grupo 'jogador' encontrado.")


func _on_jogador_morreu():
	visible = true
	AudioManager.tocar_game_over()  # corta a música e toca o sting de horror
	get_tree().paused = true


func _on_reiniciar():
	get_tree().paused = false
	AudioManager.tocar_musica()  # religa a música base (o autoload não recarrega sozinho)
	get_tree().reload_current_scene()
