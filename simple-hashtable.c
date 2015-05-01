#define _XOPEN_SOURCE 500
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct ht_entry {
	char *key;
	char *value;
	struct ht_entry *next;
};

typedef struct ht_entry ht_entry_t;

struct hashtable {
	int size;
	struct ht_entry **table;
};

typedef struct hashtable hashtable_t;

hashtable_t *ht_new(int size) {
	hashtable_t *hashtable = NULL;
	int i;

	if (size < 1)
		return NULL;
	if (!(hashtable = malloc(sizeof(hashtable_t))))
		return NULL;
	if (!(hashtable->table = calloc(size, sizeof(ht_entry_t *)))) {
		free(hashtable);
		return NULL;
	}
	hashtable->size = size;

	return hashtable;
}

int ht_jenkins_hash(hashtable_t *hashtable, char *key) {
	size_t hash = 0, i;

	for (i = 0; i < strlen(key); i++) {
		hash += key[i];
		hash += (hash << 10);
		hash ^= (hash >> 6);
	}

	hash += (hash << 3);
	hash ^= (hash >> 11);
	hash += (hash << 15);

	return hash % hashtable->size;
}

ht_entry_t *ht_pair_new(char *key, char *value) {
	ht_entry_t *this;

	if (!(this = malloc(sizeof(ht_entry_t))))
		return NULL;
	if (!(this->key = strdup(key))) {
		free(this);
		return NULL;
	}
	if (!(this->value = strdup(value))) {
		free(this->key);
		free(this);
		return NULL;
	}
	this->next = NULL;

	return this;
}

void ht_set(hashtable_t *hashtable, char *key, char *value) {
	int bin = 0;
	ht_entry_t *this = NULL;
	ht_entry_t *next = NULL;
	ht_entry_t *prev = NULL;

	bin = ht_jenkins_hash(hashtable, key);
	next = hashtable->table[bin];

	while (next && next->key && strcmp(key, next->key) > 0) {
		prev = next;
		next = next->next;
	}

	if (next && next->key && strcmp(key, next->key) == 0) {
		free(next->value);
		next->value = strdup(value);
	} else {
		this = ht_pair_new(key, value);
		if (next == hashtable->table[bin]) {
			/* We're at the start of the linked list in this bin. */
			this->next = next;
			hashtable->table[bin] = this;
		} else if (next) {
			/* We're in the middle of the list. */
			this->next = next;
			prev->next = this;
		} else {
			/* We're at the end of the linked list in this bin. */
			prev->next = this;
		}
	}
}

char *ht_get(hashtable_t *hashtable, char *key) {
	int bin = 0;
	ht_entry_t *pair;

	bin = ht_jenkins_hash(hashtable, key);

	pair = hashtable->table[bin];
	while (pair && pair->key && strcmp(key, pair->key) > 0)
		pair = pair->next;

	if (!pair || !pair->key || strcmp(key, pair->key) != 0)
		return NULL;

	return pair->value;
}


int main(int argc, char **argv) {
	hashtable_t *hashtable = ht_new(65536);

	ht_set(hashtable, "key1", "inky");
	ht_set(hashtable, "key2", "pinky");
	ht_set(hashtable, "key3", "blinky");
	ht_set(hashtable, "key4", "floyd");

	printf("%s\n", ht_get(hashtable, "key1"));
	printf("%s\n", ht_get(hashtable, "key2"));
	printf("%s\n", ht_get(hashtable, "key3"));
	printf("%s\n", ht_get(hashtable, "key4"));

	return 0;
}
