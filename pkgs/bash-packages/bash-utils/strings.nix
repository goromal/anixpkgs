{}:
rec {
    getExtension = varName: ''''${${varName}##*/}'';
    getWithoutExtension = varName: ''''${${varName}%.*}'';
    replaceExtension = varName: newExtension: ''${getWithoutExtension varName}.${newExtension}'';
}