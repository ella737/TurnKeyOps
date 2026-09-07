import { readdir, readFile, stat } from 'node:fs/promises';
import { basename, dirname, join, resolve } from 'node:path';

const buildDirectory = resolve(process.argv[2] ?? 'build');
const chunksDirectory = join(buildDirectory, 'server', 'chunks');
const manifestFiles = (await readdir(chunksDirectory)).filter((file) =>
	/^manifest\.js-.+\.js$/.test(file)
);

if (manifestFiles.length !== 1) {
	throw new Error(`Expected exactly one server manifest; found ${manifestFiles.length}.`);
}

const manifestPath = join(chunksDirectory, manifestFiles[0]);
const manifestContents = await readFile(manifestPath, 'utf8');
const referencedChunks = [
	...manifestContents.matchAll(/\b(?:from\s+|import\()\s*["'](\.\/[^"']+)["']/g)
].map(
	(match) => match[1]
);

if (referencedChunks.length === 0) {
	throw new Error('Server manifest does not declare any chunk imports.');
}

for (const relativeChunkPath of referencedChunks) {
	const chunkPath = resolve(dirname(manifestPath), relativeChunkPath);
	if (!chunkPath.startsWith(`${chunksDirectory}/`)) {
		throw new Error(`Server manifest imports outside its chunks directory: ${relativeChunkPath}`);
	}
	try {
		if (!(await stat(chunkPath)).isFile()) {
			throw new Error('not a file');
		}
	} catch {
		throw new Error(`Server manifest references a missing chunk: ${basename(chunkPath)}`);
	}
}

console.log(`Verified ${referencedChunks.length} server manifest chunk imports.`);
