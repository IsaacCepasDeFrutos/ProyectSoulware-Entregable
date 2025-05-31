# secure_config.gd
extends Node
class_name SecureConfig

const ENCRYPTION_SEED = "tu_semilla_unica_32_caracteres"  # ¡Reemplaza esto!

static func save_api_key(key: String):
	var config = ConfigFile.new()

	var aes = AESContext.new()
	var key_string = ENCRYPTION_SEED.substr(0, 32)
	var key_bytes = key_string.to_utf8_buffer()
	aes.start(0, key_bytes)

	var data = key.to_utf8_buffer()
	# AES requiere múltiplos de 16 bytes
	while data.size() % 16 != 0:
		data.append(0)

	var encrypted = aes.encrypt(data)

	config.set_value("security", "api_key", encrypted.hex_encode())
	config.save("user://config.ini")

static func load_api_key() -> String:
	var config = ConfigFile.new()
	if config.load("user://config.ini") != OK:
		return ""

	var aes = AESContext.new()
	var key_string = ENCRYPTION_SEED.substr(0, 32)
	var key_bytes = key_string.to_utf8_buffer()
	aes.start(0, key_bytes)

	var encrypted = PackedByteArray(("0x" + config.get_value("security", "api_key")).hex_to_buffer())

	var decrypted = aes.decrypt(encrypted)
	return decrypted.get_string_from_utf8().strip_edges()
