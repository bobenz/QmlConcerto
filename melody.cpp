#include "melody.h"

Melody::Melody(QObject *parent) : Phrase(parent)
{
}

void Melody::classBegin()
{
    // Implementation for parser status if needed
}

void Melody::componentComplete()
{
    // Logic to run once the QML tree is fully loaded
}

bool Melody::_play()
{
    emit enter();
    return true;
}

QQmlListProperty<Phrase> Melody::phrases()
{
    return QQmlListProperty<Phrase>(this, nullptr,
                                    &Melody::append,
                                    &Melody::count,
                                    &Melody::at,
                                    &Melody::clear);
}

QList<Phrase*> Melody::phraseList() const
{
    return m_phrases;
}

// Static Callbacks for QML Engine
void Melody::append(QQmlListProperty<Phrase> *list, Phrase *phrase)
{
    auto *self = qobject_cast<Melody *>(list->object);
    if (self && phrase) {
        phrase->setParent(self);
        self->m_phrases.append(phrase);
    }
}

int Melody::count(QQmlListProperty<Phrase> *list)
{
    auto *self = qobject_cast<Melody *>(list->object);
    return self ? self->m_phrases.count() : 0;
}

Phrase* Melody::at(QQmlListProperty<Phrase> *list, int index)
{
    auto *self = qobject_cast<Melody *>(list->object);
    return (self && index >= 0 && index < self->m_phrases.count())
               ? self->m_phrases.at(index) : nullptr;
}

void Melody::clear(QQmlListProperty<Phrase> *list)
{
    auto *self = qobject_cast<Melody *>(list->object);
    if (self) {
        self->m_phrases.clear();
    }
}
