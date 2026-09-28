"""Nigeria's states, for resolving a state-name search ("Lagos State", "FCT",
"Rivers") to the city name a listing would actually be filed under.

`Listing.city` is free text (see the model) - there is no separate state
column, matching how a Nigerian shortlet host actually describes where they
are ("Lagos", not "Lagos, Lagos State, Nigeria"). A guest who searches by
state still needs to land on real listings, so each state here maps to the
city its supply concentrates in - the state capital, in every case.
"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class NigeriaState:
    name: str
    #: The city a listing in this state is actually filed under.
    city: str
    aliases: tuple[str, ...] = field(default_factory=tuple)


NIGERIA_STATES: tuple[NigeriaState, ...] = (
    NigeriaState("Abia", "Umuahia"),
    NigeriaState("Adamawa", "Yola"),
    NigeriaState("Akwa Ibom", "Uyo"),
    NigeriaState("Anambra", "Awka"),
    NigeriaState("Bauchi", "Bauchi"),
    NigeriaState("Bayelsa", "Yenagoa"),
    NigeriaState("Benue", "Makurdi"),
    NigeriaState("Borno", "Maiduguri"),
    NigeriaState("Cross River", "Calabar"),
    NigeriaState("Delta", "Asaba"),
    NigeriaState("Ebonyi", "Abakaliki"),
    NigeriaState("Edo", "Benin City"),
    NigeriaState("Ekiti", "Ado Ekiti"),
    NigeriaState("Enugu", "Enugu"),
    NigeriaState("Gombe", "Gombe"),
    NigeriaState("Imo", "Owerri"),
    NigeriaState("Jigawa", "Dutse"),
    NigeriaState("Kaduna", "Kaduna"),
    NigeriaState("Kano", "Kano"),
    NigeriaState("Katsina", "Katsina"),
    NigeriaState("Kebbi", "Birnin Kebbi"),
    NigeriaState("Kogi", "Lokoja"),
    NigeriaState("Kwara", "Ilorin"),
    NigeriaState("Lagos", "Lagos"),
    NigeriaState("Nasarawa", "Lafia"),
    NigeriaState("Niger", "Minna"),
    NigeriaState("Ogun", "Abeokuta"),
    NigeriaState("Ondo", "Akure"),
    NigeriaState("Osun", "Osogbo"),
    NigeriaState("Oyo", "Ibadan"),
    NigeriaState("Plateau", "Jos"),
    NigeriaState("Rivers", "Port Harcourt"),
    NigeriaState("Sokoto", "Sokoto"),
    NigeriaState("Taraba", "Jalingo"),
    NigeriaState("Yobe", "Damaturu"),
    NigeriaState("Zamfara", "Gusau"),
    # Abuja is the city, FCT is the state - a guest reasonably searches either
    # word for "state", so both are recognised as naming this one entry.
    NigeriaState("Federal Capital Territory", "Abuja", aliases=("FCT", "Abuja")),
)
