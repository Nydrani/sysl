package mermaid

import "strings"

const GeneratedHeader = "%% AUTOGENERATED CODE -- DO NOT EDIT!\n\n"
const ProjectDir = "../../../"

//cleanString replaces certain characters in the string suitable for mermaid
func CleanString(temp string) string {
	temp = strings.ReplaceAll(temp, " ", "")
	temp = strings.ReplaceAll(temp, "{", "_")
	temp = strings.ReplaceAll(temp, "}", "_")
	temp = strings.ReplaceAll(temp, "[", "_")
	temp = strings.ReplaceAll(temp, "]", "_")
	temp = strings.ReplaceAll(temp, "\"", "")
	temp = strings.ReplaceAll(temp, "~", "")
	temp = strings.ReplaceAll(temp, ":", "_")
	return temp
}
